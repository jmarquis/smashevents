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

  def self.tournament(startgg_id:)
    query = <<~GRAPHQL
      query($startgg_id: ID) {
        tournament(id: $startgg_id) {
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

    client.query(query, startgg_id:)&.data&.tournament
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
