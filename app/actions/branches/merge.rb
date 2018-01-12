module Branches
  class Merge < Action::Base
    attr_accessor :branch, :other_branch

    validate :branches_not_in_conflicts

    def execute
      Revisions::PointAtGraphemes.run! ids: merge_ids,
        target: branch.working

      if no_conflicts?
        Branches::Commit.run! branch: branch
      else
        branch.working.conflict!
      end

      branch
    end

    def no_conflicts?
      @_no_conflicts ||= merge_conflicts.empty?
    end

    def merge_ids
      @_merge_ids ||= -> {
        conflict_graphemes.map(&:id).concat(branch_item_ids).
                                     concat(other_branch_ids).
                                     uniq
      }.call
    end

    def all_branch_ids(branch)
      Grapheme.connection.
        execute("select grapheme_id from #{branch.revision.graphemes_revisions_partition_table_name}").
        to_a.map { |item| item["grapheme_id"] }
    end

    def branch_item_ids
      @_branch_item_ids ||= -> {
        all_branch_ids(branch).select do |id|
          merge_conflicts.none? { |conflict| conflict.conflicting_ids.include? id }
        end
      }.call
    end

    def other_branch_ids
      @_other_branch_ids ||= -> {
        all_branch_ids(other_branch).select do |id|
          merge_conflicts.none? { |conflict| conflict.conflicting_ids.include? id }
        end
      }.call
    end

    def conflict_graphemes
      @_conflict_graphemes ||= -> {
        merge_conflicts.map do |grapheme|
          Grapheme.create! grapheme.attributes.without("id", "conflicting_ids", "surface_number").
                                               merge("status" => Grapheme.statuses[:conflict])
        end
      }.call
    end

    def merge_conflicts
      @_merge_conflicts ||= Graphemes::QueryMergeConflicts.run!(
        branch_left: branch,
        branch_right: other_branch
      ).result
    end

    def branches_not_in_conflicts
      if branch.conflict?
        errors.add(:branch, "cannot be in an unresolved conflict state")
      end

      if other_branch.conflict?
        errors.add(:other_branch, "cannot be in an unresolved conflict state")
      end
    end
  end
end
