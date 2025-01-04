class Startgg
  @client = nil

  class << self

    def tournaments(batch_size:, page:, after_date: Time.now)
      query = <<~GRAPHQL
        query($perPage: Int, $page: Int, $afterDate: Timestamp) {
          tournaments(query: {
            perPage: $perPage
            page: $page
            sortBy: "startAt asc"
            filter: {
              videogameIds: [#{Game.pluck(:startgg_id).join(',')}],
              afterDate: $afterDate
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

      StatsD.measure('startgg.tournaments') do
        client.query(query, perPage: batch_size, page:, afterDate: after_date.to_i)&.data&.tournaments&.nodes
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

      StatsD.measure('startgg.tournament') do
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

      StatsD.measure('startgg.event_entrants') do
        client.query(query, id:, perPage: batch_size, page:)&.data&.event&.entrants&.nodes
      end
    end

    def with_retries(num_retries)
      retries = 0
      result = nil

      loop do
        result = yield
        break
      rescue Graphlient::Errors::ExecutionError,
        Graphlient::Errors::FaradayServerError,
        Graphlient::Errors::ConnectionFailedError,
        Graphlient::Errors::TimeoutError,
        Faraday::ParsingError,
        OpenSSL::SSL::SSLError => e
        StatsD.increment('startgg.request_error')

        if retries < num_retries
          puts "Transient error communicating with startgg, will retry: #{e.message}"
          retries += 1
          sleep 5 * retries
          next
        else
          puts "Retry threshold exceeded, exiting: #{e.message}"
          raise e
        end
      rescue StandardError => e
        puts "Unexpected error communicating with startgg: #{e.message}"
        raise e
      end

      result
    end

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
