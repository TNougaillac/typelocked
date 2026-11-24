#===============================================================================
# FamilyCasino - Blackjack and video poker (#330)
# The cards are drawn on a felt above the map (Graphics/UI/Casino/cards), the
# choices go through the message box below them. Rules: 005_Cards.rb.
#===============================================================================
module FamilyCasino
  CARD_WIDTH  = 80
  CARD_HEIGHT = 112
  BACK_CARD   = :back   # the back of a card, at the start of the fifth row
  # Names of the video poker hands, in POKER_PAYS order.
  POKER_NAMES = {
    royal_flush: "Quinte flush royale", straight_flush: "Quinte flush", four_of_a_kind: "Carré",
    full_house: "Full", flush: "Couleur", straight: "Quinte", three_of_a_kind: "Brelan",
    two_pairs: "Double paire", jacks_or_better: "Paire de Valets ou mieux"
  }.freeze
  # Heights of the texts under the dealer's row and the player's row.
  ROW_LABELS = [122, 254].freeze

  # The felt and its two rows of cards (the dealer's above, the player's
  # below), above the map and under the message box.
  class CardTable
    FELT = Color.new(24, 92, 60)
    ROWS = [8, 140].freeze

    def initialize
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_990
      @cards = AnimatedBitmap.new("Graphics/UI/Casino/cards")
      @felt = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @felt.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, FELT)
      @overlay = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @overlay.z = 2
      pbSetSmallFont(@overlay.bitmap)
      @sprites = []
    end

    # rows: [[cards (0..51 or BACK_CARD)], ...]; labels: [[text, x, y]];
    # marks: [[row, index]] to frame.
    def show(rows, labels = [], marks = [])
      @sprites.each(&:dispose)
      @sprites = []
      @overlay.bitmap.clear
      rows.each_with_index do |cards, row|
        cards.each_with_index do |card, i|
          sprite = Sprite.new(@viewport)
          sprite.bitmap = @cards.bitmap
          sprite.z = 1
          col, line = (card == BACK_CARD) ? [0, 4] : [card % 13, card / 13]
          sprite.src_rect.set(col * CARD_WIDTH, line * CARD_HEIGHT, CARD_WIDTH, CARD_HEIGHT)
          sprite.x, sprite.y = card_position(cards.length, row, i)
          @sprites.push(sprite)
        end
      end
      marks.each do |row, i|
        x, y = card_position(rows[row].length, row, i)
        [[x - 2, y - 2, CARD_WIDTH + 4, 2], [x - 2, y + CARD_HEIGHT, CARD_WIDTH + 4, 2],
         [x - 2, y, 2, CARD_HEIGHT], [x + CARD_WIDTH, y, 2, CARD_HEIGHT]].each do |rect|
          @overlay.bitmap.fill_rect(*rect, Color.new(248, 208, 48))
        end
      end
      white = Color.new(248, 248, 248)
      shadow = Color.new(24, 40, 32)
      pbDrawTextPositions(@overlay.bitmap, labels.map { |text, x, y| [text, x, y, :center, white, shadow] })
      Graphics.update
    end

    # Top left corner of a card, the row centred (overlapping if it is long).
    def card_position(count, row, index)
      step = (count <= 1) ? 0 : [CARD_WIDTH + 6, (Graphics.width - 32 - CARD_WIDTH) / (count - 1)].min
      left = (Graphics.width - CARD_WIDTH - (step * (count - 1))) / 2
      return [left + (step * index), ROWS[row]]
    end

    def card_centre(count, row, index)
      return card_position(count, row, index)[0] + (CARD_WIDTH / 2)
    end

    def dispose
      @sprites.each(&:dispose)
      @overlay.dispose
      @felt.dispose
      @cards.dispose
      @viewport.dispose
    end
  end

  module_function

  # A line of a WorldEvents dialogue section (MapProc/Lore/dialogues.txt).
  def casino_line(section)
    return WorldEvents.line(section)
  end

  #-----------------------------------------------------------------------------
  # Blackjack
  #-----------------------------------------------------------------------------
  def blackjack
    bet = choose_bet
    return if !bet
    $player.coins -= bet
    table = CardTable.new
    begin
      deck = new_deck
      player = [deck.pop, deck.pop]
      dealer = [deck.pop, deck.pop]
      show_blackjack(table, dealer, player, true)
      pbMessage(casino_line("casino_blackjack"))
      if !blackjack?(player) && !blackjack?(dealer)
        bet = blackjack_turn(table, deck, dealer, player, bet)
        dealer_play(dealer, deck) if hand_value(player) <= 21
      end
      show_blackjack(table, dealer, player, false)
      settle(bet, blackjack_return(player, dealer, bet))
    ensure
      table.dispose
    end
  end

  # The player's turn; returns the bet, doubled or not.
  def blackjack_turn(table, deck, dealer, player, bet)
    loop do
      total = hand_value(player)
      return bet if total >= 21
      commands = [_INTL("Carte"), _INTL("Rester")]
      commands.push(_INTL("Doubler")) if player.length == 2 && $player.coins >= bet
      case pbMessage(_INTL("Tu as {1}. Le croupier montre {2}.", total, card_points(dealer[0])), commands, 2)
      when 0
        player.push(deck.pop)
      when 2
        $player.coins -= bet
        bet *= 2
        player.push(deck.pop)
        show_blackjack(table, dealer, player, true)
        return bet
      else
        return bet
      end
      show_blackjack(table, dealer, player, true)
    end
  end

  def show_blackjack(table, dealer, player, hidden)
    shown = hidden ? [dealer[0], BACK_CARD] : dealer
    labels = [[_INTL("Croupier : {1}", hidden ? "?" : hand_value(dealer)), Graphics.width / 2, ROW_LABELS[0]],
              [_INTL("Toi : {1}", hand_value(player)), Graphics.width / 2, ROW_LABELS[1]]]
    table.show([shown, player], labels)
  end
  #-----------------------------------------------------------------------------
  # Video poker
  #-----------------------------------------------------------------------------
  def video_poker
    bet = choose_bet
    return if !bet
    $player.coins -= bet
    table = CardTable.new
    begin
      deck = new_deck
      cards = Array.new(5) { deck.pop }
      table.show([[], cards])
      pbMessage(casino_line("casino_poker"))
      held = choose_holds(table, cards)
      cards = poker_draw(cards, held, deck)
      hand = poker_hand(cards)
      table.show([[], cards], [[hand ? _INTL(POKER_NAMES[hand]) : _INTL("Rien"), Graphics.width / 2, ROW_LABELS[1]]])
      settle(bet, poker_return(cards, bet))
    ensure
      table.dispose
    end
  end

  # The player moves along the five cards and a « Tirer » button, holds or
  # lets go of a card with USE, and draws on the button.
  def choose_holds(table, cards)
    held = [false] * 5
    index = 0
    loop do
      labels = held.each_with_index.filter_map do |h, i|
        [_INTL("GARDÉE"), table.card_centre(5, 1, i), ROW_LABELS[0] + 6] if h
      end
      labels.push([index == 5 ? _INTL("> Tirer <") : _INTL("Tirer"), Graphics.width / 2, ROW_LABELS[1]])
      table.show([[], cards], labels, index < 5 ? [[1, index]] : [])
      loop do
        Graphics.update
        Input.update
        if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
          index = (index + (Input.trigger?(Input::LEFT) ? 5 : 1)) % 6
          pbPlayCursorSE
          break
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          return held if index == 5
          held[index] = !held[index]
          break
        end
      end
    end
  end

  # Gives back what the hand won (the bet was paid before).
  def settle(bet, back)
    if back > bet
      $player.coins = [$player.coins + back, Settings::MAX_COINS].min
      pbSEPlay("Slots coin")
      pbMessage(_INTL("Gagné ! Tu récupères {1} jetons.", back))
    elsif back == bet
      $player.coins += back
      pbMessage(_INTL("Égalité. Tu récupères ta mise."))
    else
      pbMessage(casino_line("casino_perdu"))
    end
  end
end
