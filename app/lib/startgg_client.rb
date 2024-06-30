class StartggClient

  @@client = nil

  def self.tournaments(batch_size: 100, page: 1)
    query = <<~GRAPHQL
      query($perPage: Int, $page: Int) {
        tournaments(query: {
          perPage: $perPage
          page: $page
          sortBy: "startAt asc"
          filter: {
            upcoming: true
            videogameIds: [#{Tournament::MELEE_ID}, #{Tournament::ULTIMATE_ID}]
          }
        }) {
          nodes {
            id
            name
            slug
            startAt
            endAt
            numAttendees
            city
            addrState
            countryCode
            events(filter: {
              videogameId: [#{Tournament::MELEE_ID}, #{Tournament::ULTIMATE_ID}]
            }) {
              numEntrants
              videogame {
                id
              }
            }
          }
        }
      }
    GRAPHQL

    client.query(query, perPage: batch_size, page:)&.data&.tournaments&.nodes
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
          numAttendees
          city
          addrState
          countryCode
          events(filter: {
            videogameId: [#{Tournament::MELEE_ID}, #{Tournament::ULTIMATE_ID}]
          }) {
            numEntrants
            videogame {
              id
            }
          }
        }
      }
    GRAPHQL

    client.query(query, slug:)&.data&.tournament
  end

  def self.tournament_events_with_entrants(slug:)
    query = <<~GRAPHQL
      query($slug: String) {
        tournament(slug: $slug) {
          events(filter: {
            videogameId: [#{Tournament::MELEE_ID}, #{Tournament::ULTIMATE_ID}]
          }) {
            name
            numEntrants
            entrants(query: { page: 1, perPage: 500 }) {
              nodes {
                name
                initialSeedNum
              }
            }
            videogame {
              id
            }
          }
        }
      }
    GRAPHQL

    client.query(query, slug:)&.data&.tournament&.events
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
