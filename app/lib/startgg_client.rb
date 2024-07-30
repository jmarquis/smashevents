class StartggClient
  @@client = nil

  def self.tournaments(batch_size: 100, page: 1, after_date: Time.now)
    query = <<~GRAPHQL
      query($perPage: Int, $page: Int, $afterDate: Timestamp) {
        tournaments(query: {
          perPage: $perPage
          page: $page
          sortBy: "startAt asc"
          filter: {
            videogameIds: [#{Game::GAMES.map(&:startgg_id).join(',')}],
            afterDate: $afterDate
          }
        }) {
          nodes {
            id
            name
            slug
            startAt
            endAt
            timezone
            numAttendees
            city
            addrState
            countryCode
            events(filter: {
              videogameId: [#{Game::GAMES.map(&:startgg_id).join(',')}]
            }) {
              id
              numEntrants
              videogame {
                id
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

    client.query(query, perPage: batch_size, page:, afterDate: after_date.to_i)&.data&.tournaments&.nodes
  end

  def self.tournament(slug:)
    query = <<~GRAPHQL
      query($slug: String) {
        tournament(slug: $slug) {
          id
          name
          slug
          startAt
          endAt
          timezone
          numAttendees
          city
          addrState
          countryCode
          events(filter: {
            videogameId: [#{Game::GAMES.map(&:startgg_id).join(',')}]
          }) {
            id
            numEntrants
            videogame {
              id
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

    client.query(query, slug:)&.data&.tournament
  end

  def self.event_entrants(id:, game:, batch_size:, page:)
    query = <<~GRAPHQL
      query($id: ID, $perPage: Int, $page: Int) {
        event(id: $id) {
          entrants(query: { page: $page, perPage: $perPage }) {
            nodes {
              initialSeedNum
              participants {
                player {
                  gamerTag
                  #{game.rankings_key}: rankings(limit: 5, videogameId: #{game.startgg_id}) {
                    rank
                    title
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    client.query(query, id:, perPage: batch_size, page:)&.data&.event&.entrants&.nodes
  end

  def self.client
    return @@client if @@client

    @@client = Graphlient::Client.new(
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
