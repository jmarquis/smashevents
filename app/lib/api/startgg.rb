module Api
  class Startgg
    extend Instrumentable

    @client = nil

    class << self

      def tournaments(batch_size:, page:, after_date: Time.now, updated_after: 6.hours.ago)
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
                addrState
                city
                countryCode
                endAt
                hashtag
                id
                name
                slug
                startAt
                timezone
                events(filter: {
                  videogameId: [#{Game.pluck(:startgg_id).join(',')}]
                }) {
                  id
                  name
                  numEntrants
                  slug
                  startAt
                  state
                  teamRosterSize {
                    minPlayers
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
                  videogame {
                    id
                  }
                }
                images {
                  type
                  url
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
              addrState
              city
              countryCode
              endAt
              hashtag
              id
              name
              slug
              startAt
              timezone
              events(filter: {
                videogameId: [#{Game.pluck(:startgg_id).join(',')}]
              }) {
                id
                name
                numEntrants
                slug
                startAt
                state
                teamRosterSize {
                  minPlayers
                }
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
              images {
                type
                url
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

      def event(id:)
        query = <<~GRAPHQL
          query($id: ID) {
            event(id: $id) {
              state
            }
          }
        GRAPHQL

        instrument('event') do
          client.query(query, id:)&.data&.event
        end
      end

      def event_entrants(event_id:, game:, batch_size:, page:)
        query = <<~GRAPHQL
          query($id: ID, $perPage: Int, $page: Int) {
            event(id: $id) {
              entrants(query: { page: $page, perPage: $perPage }) {
                nodes {
                  id
                  initialSeedNum
                  name
                  participants {
                    player {
                      gamerTag
                      id
                      #{game.rankings_key}: rankings(limit: 5, videogameId: #{game.startgg_id}) {
                        rank
                        title
                      }
                      user {
                        discriminator
                        id
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
          client.query(query, id: event_id, perPage: batch_size, page:)&.data&.event&.entrants&.nodes
        end
      end

      def in_progress_sets(event_id:, batch_size: 20, page: 1)
        query = <<~GRAPHQL
          query($id: ID, $perPage: Int, $page: Int) {
            event(id: $id) {
              sets(
                perPage: $perPage,
                page: $page,
                filters: {
                  state: [#{Event::SET_STATE_IN_PROGRESS}]
                }
              ) {
                nodes {
                  completedAt
                  id
                  startedAt
                  state
                  winnerId
                  phaseGroup {
                    bracketType
                  }
                  slots {
                    entrant {
                      id
                      name
                      participants {
                        player {
                          id
                        }
                      }
                    }
                    standing {
                      stats {
                        score {
                          value
                        }
                      }
                    }
                  }
                  stream {
                    streamName
                    streamSource
                  }
                }
              }
            }
          }
        GRAPHQL

        instrument('in_progress_sets') do
          client.query(query, id: event_id, perPage: batch_size, page:)&.data&.event&.sets&.nodes
        end
      end

      def completed_sets(event_id:, batch_size: 20, page: 1, updated_after: 1.hour.ago)
        query = <<~GRAPHQL
          query($id: ID, $perPage: Int, $page: Int, $updatedAfter: Timestamp) {
            event(id: $id) {
              sets(
                perPage: $perPage,
                page: $page,
                filters: {
                  state: [#{Event::SET_STATE_COMPLETED}],
                  updatedAfter: $updatedAfter
                }
              ) {
                nodes {
                  completedAt
                  id
                  startedAt
                  state
                  winnerId
                  phaseGroup {
                    bracketType
                  }
                  slots {
                    entrant {
                      id
                      name
                      participants {
                        player {
                          id
                        }
                      }
                    }
                    standing {
                      stats {
                        score {
                          value
                        }
                      }
                    }
                  }
                  stream {
                    streamName
                    streamSource
                  }
                }
              }
            }
          }
        GRAPHQL

        instrument('completed_sets') do
          client.query(query, id: event_id, perPage: batch_size, page:, updatedAfter: updated_after.to_i)&.data&.event&.sets&.nodes
        end
      end

      def set(set_id)
        query = <<~GRAPHQL
          query($setId: ID!) {
            set(id: $setId) {
              completedAt
              id
              startedAt
              state
              winnerId
              phaseGroup {
                bracketType
              }
              slots {
                entrant {
                  id
                  name
                  participants {
                    player {
                      id
                    }
                  }
                }
                standing {
                  stats {
                    score {
                      value
                    }
                  }
                }
              }
              stream {
                streamName
                streamSource
              }
            }
          }
        GRAPHQL

        instrument('set') do
          client.query(query, setId: set_id)&.data&.set
        end
      end

      def with_retries(max_retries, batch_size: nil)
        retries = 0
        result = nil

        loop do
          result = if batch_size.present?
            yield batch_size
          else
            yield
          end

          break
        rescue Graphlient::Errors::GraphQLError => e
          raise e unless e.message.match?(/query complexity/)
          raise e unless batch_size.present?

          if retries >= max_retries
            Rails.logger.info "Retry threshold exceeded, exiting: #{e.message}"
            raise e
          end

          retries += 1

          if batch_size.present?
            batch_size = (batch_size * 0.9).round == batch_size ? batch_size - 1 : (batch_size * 0.9).round
          end

          Rails.logger.info "Query complexity error, reducing batch size and retrying. New batch size: #{batch_size}. Retry ##{retries}..."

          sleep 5 * retries

          next
        rescue Graphlient::Errors::ExecutionError,
          Graphlient::Errors::FaradayServerError,
          Graphlient::Errors::ConnectionFailedError,
          Graphlient::Errors::TimeoutError,
          Faraday::ParsingError,
          Faraday::SSLError,
          OpenSSL::SSL::SSLError => e
          StatsD.increment('startgg.request_error')

          if retries >= max_retries
            Rails.logger.info "Retry threshold exceeded, exiting: #{e.message}"
            raise e
          end

          Rails.logger.info "Transient error communicating with startgg, will retry: #{e.message}"
          retries += 1

          sleep 5 * retries

          next
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
end
