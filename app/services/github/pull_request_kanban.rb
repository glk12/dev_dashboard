module Github
  class PullRequestKanban
    COLUMNS = {
      draft: "Draft",
      waiting_review: "Waiting Review",
      changes_requested: "Changes Requested",
      approved: "Approved",
    }.freeze

    def initialize(pull_requests)
      @pull_requests = pull_requests
    end

    # Returns a hash with each column and its matching pull requests
    def columns
      COLUMNS.keys.index_with do |column|
        pull_requests_for(column)
      end
    end

    def column_title(column)
      COLUMNS.fetch(column)
    end

    private

    # Filters pull requests that belong to the given column
    def pull_requests_for(column)
      @pull_requests.select do |pull_request|
        column_for(pull_request) == column
      end
    end

    # Returns which column a pull request belongs to
    def column_for(pull_requests)
      return :draft if pull_requests[:draft]
      return :changes_requested if pull_requests[:review_state] == "CHANGES_REQUESTED"
      return :approved if pull_requests[:review_state] == "APPROVED"
      :waiting_review
    end
  end
end
