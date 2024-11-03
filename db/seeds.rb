melee = Game.find_or_create_by!(slug: 'melee')
melee.update!(
  name: 'Melee',
  twitch_name: 'Super Smash Bros. Melee',
  startgg_id: 1,
  rankings_regex: /^SSBMRank/,
  ingestion_threshold: 8,
  display_threshold: 100
)

ultimate = Game.find_or_create_by!(slug: 'ultimate')
ultimate.update!(
  name: 'Ultimate',
  twitch_name: 'Super Smash Bros. Ultimate',
  startgg_id: 1386,
  rankings_regex: /^UltRank/,
  ingestion_threshold: 8,
  display_threshold: 200
)

smash64 = Game.find_or_create_by!(slug: 'smash64')
smash64.update!(
  name: 'Smash 64',
  twitch_name: 'Super Smash Bros.',
  startgg_id: 4,
  rankings_regex: /^The SSB64 League Rankings/,
  ingestion_threshold: 8,
  display_threshold: 30
)

rivals = Game.find_or_create_by!(slug: 'rivals')
rivals.update!(
  name: 'Rivals',
  twitch_name: 'Rivals of Aether',
  startgg_id: 24,
  rankings_regex: /^NA RCS/,
  ingestion_threshold: 8,
  display_threshold: 40
)

rivals2 = Game.find_or_create_by!(slug: 'rivals2')
rivals2.update!(
  name: 'Rivals 2',
  twitch_name: 'Rivals 2',
  startgg_id: 53945,
  rankings_regex: /^NA RCS/,
  ingestion_threshold: 8,
  display_threshold: 60
)
