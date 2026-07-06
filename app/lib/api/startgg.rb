module Api
  class Startgg
    extend Instrumentable

    @client = nil

    class << self

      def tournaments(
        batch_size:,
        page:,
        before_date: nil,
        after_date: nil,
        updated_after: nil,
        sort_order: nil
      )
        instrument('tournaments') do
          client.query(
            {
              perPage: batch_size,
              page:,
              beforeDate: before_date&.to_i,
              afterDate: after_date&.to_i,
              updatedAfter: updated_after&.to_i,
              sortBy: sort_order == Provider::Base::SORT_ORDER_NEWEST_FIRST ? 'endAt desc' : 'startAt asc'
            }.compact
          ) do
            query({
              perPage: :int!,
              page: :int!,
              beforeDate: before_date.present? ? :Timestamp : nil,
              afterDate: after_date.present? ? :Timestamp : nil,
              updatedAfter: updated_after.present? ? :Timestamp : nil,
              sortBy: :string!
            }.compact) do
              tournaments(query: {
                perPage: :perPage,
                page: :page,
                sortBy: :sortBy,
                filter: {
                  videogameIds: Game.pluck(:startgg_id),
                  beforeDate: before_date.present? ? :beforeDate : nil,
                  afterDate: after_date.present? ? :afterDate : nil,
                  computedUpdatedAt: updated_after.present? ? :updatedAfter : nil
                }.compact
              }.compact) do
                nodes do
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
                    videogameId: Game.pluck(:startgg_id)
                  }) do
                    id
                    name
                    numEntrants
                    slug
                    startAt
                    state

                    teamRosterSize do
                      minPlayers
                    end

                    standings(query: {
                      sortBy: 'placement desc',
                      page: 1,
                      perPage: 1
                    }) do
                      nodes do
                        isFinal

                        entrant do
                          id
                        end
                      end
                    end

                    videogame do
                      id
                    end
                  end

                  images do
                    type
                    url
                  end

                  streams do
                    streamName
                    streamSource
                    streamStatus
                  end
                end
              end
            end
          end&.data&.tournaments&.nodes
        end
      end

      def tournament(slug:)
        instrument('tournament') do
          client.query(slug:) do
            query(slug: :string) do
              tournament(slug: :slug) do
                addrState
                city
                countryCode
                endAt
                hashtag
                id
                name
                slug() # rubocop:disable Style/MethodCallWithoutArgsParentheses
                startAt
                timezone

                events(filter: {
                  videogameId: Game.pluck(:startgg_id)
                }) do
                  id
                  name
                  numEntrants
                  slug() # rubocop:disable Style/MethodCallWithoutArgsParentheses
                  startAt
                  state

                  teamRosterSize do
                    minPlayers
                  end

                  videogame do
                    id
                  end

                  standings(query: {
                    sortBy: 'placement desc',
                    page: 1,
                    perPage: 1
                  }) do
                    nodes do
                      isFinal

                      entrant do
                        id
                      end
                    end
                  end
                end

                images do
                  type
                  url
                end

                streams do
                  streamName
                  streamSource
                  streamStatus
                end
              end
            end
          end&.data&.tournament
        end
      end

      def event(id:)
        instrument('event') do
          client.query(id:) do
            query(id: :id) do
              event(id: :id) do
                state
              end
            end
          end&.data&.event
        end
      end

      def event_entrants(event_id:, game:, batch_size:, page:)
        instrument('event_entrants') do
          client.query(
            event_id:,
            perPage: batch_size,
            page:,
            authorization_types: ['TWITTER']
          ) do
            query(
              event_id: :id,
              perPage: :int,
              page: :int,
              authorization_types: '[SocialConnectionType]'
            ) do
              event(id: :event_id) do
                entrants(query: {
                  page: :page,
                  perPage: :perPage
                }) do
                  nodes do
                    id
                    initialSeedNum
                    name

                    participants do
                      player do
                        gamerTag
                        id

                        send("#{game.rankings_key}: rankings", limit: 5, videogameId: game.startgg_id) do
                          rank
                          title
                        end

                        user do
                          discriminator
                          id
                          name

                          authorizations(types: :authorization_types) do
                            externalUsername
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end&.data&.event&.entrants&.nodes
        end
      end

      def in_progress_sets(event_id:, batch_size: 20, page: 1)
        instrument('in_progress_sets') do
          client.query(
            event_id:,
            perPage: batch_size,
            page:
          ) do
            query(
              event_id: :id,
              perPage: :int,
              page: :int
            ) do
              event(id: :event_id) do
                sets(
                  perPage: :perPage,
                  page: :page,
                  filters: {
                    state: [Event::SET_STATE_IN_PROGRESS]
                  }
                ) do
                  nodes do
                    completedAt
                    id
                    startedAt
                    state
                    winnerId

                    phaseGroup do
                      bracketType
                    end

                    slots do
                      entrant do
                        id
                        name

                        participants do
                          player do
                            id
                          end
                        end
                      end

                      standing do
                        stats do
                          score do
                            value
                          end
                        end
                      end
                    end

                    stream do
                      streamName
                      streamSource
                    end
                  end
                end
              end
            end
          end&.data&.event&.sets&.nodes
        end
      end

      def completed_sets(event_id:, batch_size: 20, page: 1, updated_after: 1.hour.ago)
        instrument('completed_sets') do
          client.query(
            event_id:,
            perPage: batch_size,
            page:,
            updatedAfter: updated_after&.to_i
          ) do
            query(
              event_id: :id,
              perPage: :int,
              page: :int,
              updatedAfter: :Timestamp
            ) do
              event(id: :event_id) do
                sets(
                  perPage: :perPage,
                  page: :page,
                  filters: {
                    state: [Event::SET_STATE_COMPLETED],
                    updatedAfter: :updatedAfter
                  }
                ) do
                  nodes do
                    completedAt
                    id
                    startedAt
                    state
                    winnerId

                    phaseGroup do
                      bracketType
                    end

                    slots do
                      entrant do
                        id
                        name

                        participants do
                          player do
                            id
                          end
                        end
                      end

                      standing do
                        stats do
                          score do
                            value
                          end
                        end
                      end
                    end

                    stream do
                      streamName
                      streamSource
                    end
                  end
                end
              end
            end
          end&.data&.event&.sets&.nodes
        end
      end

      def set(id)
        instrument('set') do
          client.query(id:) do
            query(id: :id!) do
              set(id: :id) do
                completedAt
                id() # rubocop:disable Style/MethodCallWithoutArgsParentheses
                startedAt
                state
                winnerId

                phaseGroup do
                  bracketType
                end

                slots do
                  entrant do
                    id() # rubocop:disable Style/MethodCallWithoutArgsParentheses
                    name

                    participants do
                      player do
                        id()
                      end
                    end
                  end

                  standing do
                    stats do
                      score do
                        value
                      end
                    end
                  end
                end

                stream do
                  streamName
                  streamSource
                end
              end
            end
          end&.data&.set
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
        @client ||= Graphlient::Client.new(
          'https://api.start.gg/gql/alpha',
          headers: {
            'Authorization' => "Bearer #{Rails.application.credentials.dig(:startgg, :token)}"
          },
          http_options: {
            read_timeout: 60,
            write_timeout: 30
          }
        )
      end

    end
  end
end
