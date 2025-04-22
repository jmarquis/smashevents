class Startgg < Api
  @client = nil

  class << self

    def tournaments(batch_size:, page:, after_date: Time.now, updated_after: Time.now - 6.hours)
      query = <<~GRAPHQL
        query($perPage: Int, $page: Int, $afterDate: Timestamp, $updatedAfter: Timestamp) {
          tournaments(query: {
            perPage: $perPage
            page: $page
            sortBy: "startAt asc"
            filter: {
              videogameIds: [#{Game.pluck(:startgg_id).join(',')}],
              afterDate: $afterDate,
              computedUpdatedAt: $updatedAfter
            }
          }) {
            nodes {
              id
              name
              slug
              hashtag
              startAt
              endAt
              timezone
              city
              addrState
              countryCode
              images {
                type
                url
              }
              events(filter: {
                videogameId: [#{Game.pluck(:startgg_id).join(',')}]
              }) {
                id
                slug
                state
                startAt
                numEntrants
                videogame {
                  id
                }
                standings(query: {
                  sortBy: "placement desc",
                  page: 1,
                  perPage: 1
                }) {
                  nodes {
                    isFinal
                    entrant {
                      id
                    }
                  }
                }
              }
              streams {
                streamName
                streamSource
                streamStatus
              }
            }
          }
        }
      GRAPHQL

      instrument('tournaments') do
        client.query(query, perPage: batch_size, page:, afterDate: after_date.to_i, updatedAfter: updated_after.to_i)&.data&.tournaments&.nodes
      end
    end

    def tournament(slug:)
      query = <<~GRAPHQL
        query($slug: String) {
          tournament(slug: $slug) {
            id
            name
            slug
            hashtag
            startAt
            endAt
            timezone
            city
            addrState
            countryCode
            images {
              type
              url
            }
            events(filter: {
              videogameId: [#{Game.pluck(:startgg_id).join(',')}]
            }) {
              id
              slug
              state
              startAt
              numEntrants
              videogame {
                id
              }
              standings(query: {
                sortBy: "placement desc",
                page: 1,
                perPage: 1
              }) {
                nodes {
                  isFinal
                  entrant {
                    id
                  }
                }
              }
            }
            streams {
              streamName
              streamSource
              streamStatus
            }
          }
        }
      GRAPHQL

      instrument('tournament') do
        client.query(query, slug:)&.data&.tournament
      end
    end

    def event_entrants(id:, game:, batch_size:, page:)
      query = <<~GRAPHQL
        query($id: ID, $perPage: Int, $page: Int) {
          event(id: $id) {
            entrants(query: { page: $page, perPage: $perPage }) {
              nodes {
                id
                name
                initialSeedNum
                participants {
                  player {
                    id
                    gamerTag
                    #{game.rankings_key}: rankings(limit: 5, videogameId: #{game.startgg_id}) {
                      rank
                      title
                    }
                    user {
                      id
                      slug
                      name
                      authorizations(types: [TWITTER]) {
                        externalUsername
                      }
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      instrument('event_entrants') do
        client.query(query, id:, perPage: batch_size, page:)&.data&.event&.entrants&.nodes
      end
    end

    def sets(event_id, batch_size: 50, page: 1)
      query = <<~GRAPHQL
        query($id: ID, $perPage: Int, $page: Int) {
          event(id: $id) {
            sets(
              perPage: $perPage,
              page: $page,
              filters: {
                state: 2
              }
            ) {
              nodes {
                completedAt
                id
                slots {
                  entrant {
                    name
                    participants {
                      player {
                        id
                      }
                    }
                  }
                }
                startedAt
                state
                stream {
                  streamName
                  streamSource
                }
              }
            }
          }
        }
      GRAPHQL

      instrument('sets') do
        client.query(query, id: event_id, perPage: batch_size, page:)&.data&.event&.sets&.nodes
      end
    end

    def with_retries(num_retries, batch_size: nil)
      retries = 0
      result = nil

      loop do
        result = yield batch_size
        break
      rescue Graphlient::Errors::GraphQLError => e
        raise e unless e.message.match? /query complexity/
        raise e unless batch_size.present?

        if retries < num_retries
          Rails.logger.info "Query complexity error, reducing batch size"
          batch_size -= 1
          sleep 5 * retries
          next
        else
          Rails.logger.info "Retry threshold exceeded, exiting: #{e.message}"
          raise e
        end
      rescue Graphlient::Errors::ExecutionError,
        Graphlient::Errors::FaradayServerError,
        Graphlient::Errors::ConnectionFailedError,
        Graphlient::Errors::TimeoutError,
        Faraday::ParsingError,
        Faraday::SSLError,
        OpenSSL::SSL::SSLError => e
        StatsD.increment('startgg.request_error')

        if retries < num_retries
          Rails.logger.info "Transient error communicating with startgg, will retry: #{e.message}"
          retries += 1
          sleep 5 * retries
          next
        else
          Rails.logger.info "Retry threshold exceeded, exiting: #{e.message}"
          raise e
        end
      rescue StandardError => e
        Rails.logger.error "Unexpected error communicating with startgg: #{e.message}"
        raise e
      end

      result
    end

    private

    def client
      return @client if @client

      @client = Graphlient::Client.new(
        'https://api.start.gg/gql/alpha',
        headers: {
          'Authorization' => "Bearer #{Rails.application.credentials.dig(:startgg, :token)}"
        },
        http_options: {
          read_timeout: 20,
          write_timeout: 30
        }
      )
    end

  end
end
