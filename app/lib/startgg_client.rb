class StartggClient

  RANKINGS_KEY_MELEE = :melee_rankings
  RANKINGS_KEY_ULTIMATE = :ultimate_rankings

  RANKINGS_KEY_MAP = {
    Tournament::MELEE_ID => RANKINGS_KEY_MELEE,
    Tournament::ULTIMATE_ID => RANKINGS_KEY_ULTIMATE
  }

  RANKINGS_REGEX_MAP = {
    Tournament::MELEE_ID => /^SSBMRank/,
    Tournament::ULTIMATE_ID => /^UltRank/
  }

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
            timezone
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
          timezone
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

  def self.tournament_events(slug:)
    query = <<~GRAPHQL
      query($slug: String) {
        tournament(slug: $slug) {
          events(filter: {
            videogameId: [#{Tournament::MELEE_ID}, #{Tournament::ULTIMATE_ID}]
          }) {
            id
            name
            numEntrants
            videogame {
              id
            }
          }
        }
      }
    GRAPHQL

    client.query(query, slug:)&.data&.tournament&.events
  end

  def self.event_entrants(id:, batch_size:, page:)
    query = <<~GRAPHQL
      query($id: ID, $perPage: Int, $page: Int) {
        event(id: $id) {
          entrants(query: { page: $page, perPage: $perPage }) {
            nodes {
              initialSeedNum
              participants {
                player {
                  gamerTag
                  #{RANKINGS_KEY_MELEE}: rankings(limit: 5, videogameId: #{Tournament::MELEE_ID}) {
                    rank
                    title
                  }
                  #{RANKINGS_KEY_ULTIMATE}: rankings(limit: 5, videogameId: #{Tournament::ULTIMATE_ID}) {
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
