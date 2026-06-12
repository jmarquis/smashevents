melee = Game.find_or_create_by!(slug: 'melee')
melee.update!(
  sort_order: 1,
  name: 'Melee',
  twitch_name: 'Super Smash Bros. Melee',
  hashtag: 'ssbm',
  startgg_id: 1,
  parrygg_id: '01920676-416e-7838-b6aa-8d4453256f05',
  rankings_regex: /^SSBMRank/,
  ingestion_threshold: 8,
  display_threshold: 100,
  # doubles_display_threshold: 50
)

ultimate = Game.find_or_create_by!(slug: 'ultimate')
ultimate.update!(
  sort_order: 2,
  name: 'Ultimate',
  twitch_name: 'Super Smash Bros. Ultimate',
  hashtag: 'ssbu',
  startgg_id: 1386,
  parrygg_id: '01920676-416e-7b49-a669-7157bd4a6934',
  rankings_regex: /^UltRank|^LumiRank/,
  ingestion_threshold: 8,
  display_threshold: 200,
  # doubles_display_threshold: 100
)

smash64 = Game.find_or_create_by!(slug: 'smash64')
smash64.update!(
  sort_order: 3,
  name: 'Smash 64',
  twitch_name: 'Super Smash Bros.',
  hashtag: 'ssb64',
  startgg_id: 4,
  parrygg_id: '0199e44b-0626-7b5e-a7ad-088dff8254ad',
  rankings_regex: /^The SSB64 League Rankings/,
  ingestion_threshold: 8,
  display_threshold: 30
)

remix = Game.find_or_create_by!(slug: 'remix')
remix.update!(
  sort_order: 4,
  name: 'Remix',
  twitch_name: 'Super Smash Bros.',
  hashtag: 'smashremix',
  startgg_id: 39478,
  parrygg_id: '019e6111-efad-78d7-a861-2edf42e0eec9',
  rankings_regex: /^The SSB64 League Rankings/,
  ingestion_threshold: 8,
  display_threshold: 30
)

rivals = Game.find_or_create_by!(slug: 'rivals')
rivals.update!(
  sort_order: 5,
  name: 'Rivals 1',
  twitch_name: 'Rivals of Aether',
  hashtag: 'RivalsOfAether',
  startgg_id: 24,
  parrygg_id: '019b422d-e5f2-77a1-9228-ba4163d7c6cc',
  rankings_regex: /^NA RCS/,
  ingestion_threshold: 8,
  display_threshold: 20
)

rivals2 = Game.find_or_create_by!(slug: 'rivals2')
rivals2.update!(
  sort_order: 6,
  name: 'Rivals 2',
  twitch_name: 'Rivals 2',
  hashtag: 'RivalsOfAether2',
  startgg_id: 53945,
  parrygg_id: '01951d83-6be9-734e-9533-0db8e881e149',
  rankings_regex: /^NA RCS/,
  ingestion_threshold: 8,
  display_threshold: 60,
  # doubles_display_threshold: 40
)
