#===============================================================================
# DailyChallenge - The day and its seed
# Pure functions (no game state): the CI checks them.
#===============================================================================
require "zlib"

module DailyChallenge
  module_function

  # The day of the computer, as "2026-11-02" (it changes at local midnight).
  def today(time = Time.now)
    return time.strftime("%Y-%m-%d")
  end

  # Seed of that day's world: the same on every computer, whatever its Ruby.
  def seed_for(date)
    return Zlib.crc32("#{SEED_SALT} #{date}") % SEED_RANGE
  end

  # "02/11" for "2026-11-02".
  def short_date(date)
    _year, month, day = date.split("-")
    return "#{day}/#{month}"
  end

  # [type, starters] of that seed's challenge, drawn from types (in their
  # PBS order) and the starter pool of the type (pool_for.call(type)).
  def draw(seed, types, pool_for, count)
    rng = Random.new(seed ^ DRAW_SALT)
    type = types[rng.rand(types.length)]
    return type, pool_for.call(type).sample(count, random: rng)
  end
end
