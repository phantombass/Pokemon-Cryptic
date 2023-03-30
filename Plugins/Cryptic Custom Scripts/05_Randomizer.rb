class PokemonGlobalMetadata
  attr_accessor :randomizedData
end

class Randomizer
	def self.all_species
	    keys = []
	    GameData::Species.each { |species| keys.push(species.id) if species.form == 0 }
	    return keys
	end

    def self.all_types
        keys = []
        GameData::Type.each { |type| keys.push(type.id)}
        return keys
    end

    def self.generate_dungeon_types
        types = self.all_types
        type = []
        loop do
            t = types[rand(types.length)]
            type.push(t) if !type.include?(t)
            break if type.length == 6
        end
        $game_variables[90] = type
    end

	def self.levelRand
		lvl = [5,15,25,30,35,45,55,65,75,75,75,75,75]
        level = lvl[$game_system.level_cap] - rand(3)
        level = 1 if level < 1
		return lvl[$game_system.level_cap]
	end

	def self.getRandomizedData(data, symbol, index = nil)
	    if $PokemonGlobal && $PokemonGlobal.randomizedData && $PokemonGlobal.randomizedData.has_key?(symbol)
	      return $PokemonGlobal.randomizedData[symbol][index] if !index.nil?
	      return $PokemonGlobal.randomizedData[symbol]
	    end
	    return data
	  end

	def self.randomizeEncounters
	    # loads map encounters
	    data = load_data("Data/encounters.dat")
	    return if !data.is_a?(Hash) # failsafe
	    # iterates through each map point
	    for key in data.keys
	      # go through each encounter type
	      for type in data[key].types.keys
	        # cycle each definition
	        for i in 0...data[key].types[type].length
	          # set randomized species
	          data[key].types[type][i][1] = self.all_species.sample
	        end
	      end
	    end
	    $game_variables[61] = data
	    return data
	end

	def self.randomizeStarters
	  # if defined as an exclusion rule, species will not be randomized
	  # randomizes static encounters
	  species = self.all_species
	  starters = []
	  starter_names = []
	  loop do
		 mon = species[rand(species.length)]
         flags = GameData::Species.get(mon).flags
		 starters.push(mon) if !starters.include?(mon) && !["Legendary","UltraBeast","Paradox"].include?(flags)
		 break if starters.length == 3
	  end
	  for i in 0...starters.length
	  	starter_names.push(starters[i].name)
	  end
	  $game_variables[65] = starters
	  $game_variables[62] = starter_names[0]
	  $game_variables[63] = starter_names[1]
	  $game_variables[64] = starter_names[2]
	  return starters
	end

	def self.randomizeTrainers
        list = [:LEADER_Brock,:LEADER_Misty,:LEADER_Surge,:LEADER_Erika,:LEADER_Koga,:LEADER_Sabrina,:LEADER_Blaine,:LEADER_Giovanni]
        league = [:ELITEFOUR_Lorelei,:ELITEFOUR_Bruno,:ELITEFOUR_Agatha,:ELITEFOUR_Lance]
        pick = 0
        new_list = []
        league_list = []
        ver = []
        loop do
            c = rand(list.length)
            choice = list[c]
            next if new_list.include?(choice)
            new_list.push(choice)
            pick += 1
            break if pick == list.length
        end
        loop do
            c = rand(league.length)
            choice = league[c]
            next if league_list.include?(choice)
            league_list.push(choice)
            pick += 1
            break if pick == league.length
        end
        for i in 0...new_list.length
            l = 0
            ver.push(l)
            l += 1 if l < 3
        end
        $game_variables[80] = new_list
        $game_variables[81] = league_list
        $game_variables[82] = ver
    end
end

def trainerForm(trainer_type,num)
    form = $game_variables[82]
    tr = $game_variables[80]
    idx = 0
    for i in tr
        break if i == trainer_type
        idx += 1
    end
    return form[idx][num]
end

def randomizeSpecies(species, static = false, gift = false)
  pokemon = nil
  if species.is_a?(Pokemon)
    pokemon = species.clone
    species = pokemon.species
  end
  if !pokemon.nil?
    pokemon.species = species
    pokemon.calc_stats
    pokemon.reset_moves
  end
  return pokemon.nil? ? species : pokemon
end

alias pbBattleOnStepTaken_randomizer pbBattleOnStepTaken unless defined?(pbBattleOnStepTaken_randomizer)
def pbBattleOnStepTaken(*args)
  $nonStaticEncounter = true
  pbBattleOnStepTaken_randomizer(*args)
  $nonStaticEncounter = false
end
#===============================================================================
#  aliasing to randomize static battles
#===============================================================================
class WildBattle
  # Used when walking in tall grass, hence the additional code.
  def self.start(*args, can_override: false)
    foe_party = WildBattle.generate_foes(*args)
    # Potentially call a different WildBattle.start-type method instead (for
    # roaming Pokémon, Safari battles, Bug Contest battles)
    spec = Randomizer.all_species
    randMon = spec[rand(spec.length)]
    flags = GameData::Species.get(randMon).flags
    foe_party[0].species = randMon if !["Legendary","UltraBeast","Paradox"].include?(flags)
    foe_party[0].level = Randomizer.levelRand
    foe_party[0].reset_moves
    foe_party[0].calc_stats
    if foe_party.length == 1 && can_override
      handled = [nil]
      EventHandlers.trigger(:on_calling_wild_battle, foe_party[0].species, foe_party[0].level, handled)
      return handled[0] if !handled[0].nil?
    end
    # Perform the battle
    outcome = WildBattle.start_core(*foe_party)
    # Used by the Poké Radar to update/break the chain
    if foe_party.length == 1 && can_override
      EventHandlers.trigger(:on_wild_battle_end, foe_party[0].species, foe_party[0].level, outcome)
    end
    # Return false if the player lost or drew the battle, and true if any other result
    return outcome != 2 && outcome != 5
  end
end