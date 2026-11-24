#===============================================================================
# DailyChallenge - Best scores in RunHistory
# Each time RunHistory records the game, a challenge game becomes its day's
# best if it scores more. The list of every game gets a « Défis du jour »
# view: the best game of each day kept, the most recent first.
#===============================================================================
module RunHistory
  class << self
    alias_method :__daily_challenge_record, :record
    alias_method :__daily_challenge_extra_views, :extra_views

    def record(*args)
      __daily_challenge_record(*args)
      DailyChallenge.keep_best
    end

    def extra_views
      days = DailyChallenge.best_days
      dates = days.to_h { |date, entry| [entry.id, date] }
      label = ->(entry) { "#{DailyChallenge.short_date(dates[entry.id])} · #{RunHistory.line(entry, false)}" }
      view = View.new(_INTL("Défis"), ->(_i, _n) { _INTL("Défis du jour") }, days.map(&:last), false, label)
      return __daily_challenge_extra_views + [view]
    end
  end
end
