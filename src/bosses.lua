-- Boss roster, attack actions, and damage application
local Bosses = {}

-- Attack functions return an action table or nil
local function no_attack(boss, run)
    return nil
end

local function detention_attack(boss, run)
    -- Fires every 2 hands played
    if run.hands_played > 0 and run.hands_played % 2 == 0 then
        return {
            type    = "debuff",
            effect  = "reduce_hand_size",
            amount  = 1,
            rounds  = 2,
            message = "DETENTION! Hand size reduced by 1 for 2 rounds!",
        }
    end
    return nil
end

local function shame_attack(boss, run)
    if boss.stage >= 2 then
        return {
            type    = "shame",
            message = "She adds SHAME to your deck! (-5 Chips if played)",
        }
    end
    return nil
end

local ROSTER = {
    {
        id          = "head_pharmacist",
        name        = "Head Pharmacist",
        title       = "The Composure Queen",
        max_hp      = 100,
        max_stages  = 3,
        -- HP percent thresholds that trigger the next stage (checked without elseif)
        stage_thresholds = { 0.6, 0.0 },
        dialogue = {
            [1] = "Ready for your appointment?",
            [2] = "You're making me... very nervous...",
            [3] = "Oh my... what a thorough examination!",
        },
        stage_colors = {
            [1] = {0.12, 0.12, 0.38},
            [2] = {0.52, 0.12, 0.52},
            [3] = {0.88, 0.52, 0.08},
        },
        on_player_hand = no_attack,
        gold_reward    = 15,
        tier           = 1,
    },
    {
        id          = "strict_professor",
        name        = "Strict Professor",
        title       = "The Academic Authority",
        max_hp      = 150,
        max_stages  = 3,
        stage_thresholds = { 0.66, 0.33 },
        dialogue = {
            [1] = "This behavior is highly irregular.",
            [2] = "I... may need to revise my grading rubric.",
            [3] = "Extra credit... for everyone.",
        },
        stage_colors = {
            [1] = {0.05, 0.22, 0.05},
            [2] = {0.42, 0.32, 0.04},
            [3] = {0.82, 0.62, 0.12},
        },
        on_player_hand = detention_attack,
        gold_reward    = 20,
        tier           = 2,
    },
    {
        id          = "ceo_of_sin",
        name        = "CEO of Sin",
        title       = "The Corporate Dominatrix",
        max_hp      = 200,
        max_stages  = 4,
        stage_thresholds = { 0.75, 0.5, 0.25 },
        dialogue = {
            [1] = "My time is extremely valuable.",
            [2] = "Interesting. You have my attention.",
            [3] = "The boardroom has never seen anything like this.",
            [4] = "Merger... fully approved.",
        },
        stage_colors = {
            [1] = {0.10, 0.02, 0.02},
            [2] = {0.42, 0.07, 0.07},
            [3] = {0.72, 0.14, 0.32},
            [4] = {0.92, 0.32, 0.52},
        },
        on_player_hand = shame_attack,
        gold_reward    = 30,
        tier           = 3,
    },
}

-- Returns a fresh independent copy of boss at roster index
function Bosses.get(index)
    local def = ROSTER[index]
    if not def then return nil end
    local boss = {
        id               = def.id,
        name             = def.name,
        title            = def.title,
        max_hp           = def.max_hp,
        hp               = def.max_hp,
        max_stages       = def.max_stages,
        stage            = 1,
        stage_thresholds = {},
        dialogue         = {},
        stage_colors     = {},
        on_player_hand   = def.on_player_hand,
        gold_reward      = def.gold_reward,
        tier             = def.tier,
    }
    for i, v in ipairs(def.stage_thresholds) do
        boss.stage_thresholds[i] = v
    end
    for i, v in ipairs(def.dialogue) do
        boss.dialogue[i] = v
    end
    for i, v in ipairs(def.stage_colors) do
        boss.stage_colors[i] = {v[1], v[2], v[3]}
    end
    return boss
end

-- Apply damage and advance stage if thresholds crossed.
-- Bug-1 fix: uses plain if checks, not elseif, so a single hit that skips
-- multiple thresholds correctly lands on the final stage.
-- Returns: { stage_changed, new_stage, defeated }
function Bosses.apply_damage(boss, damage)
    boss.hp = math.max(0, boss.hp - damage)
    local old_stage = boss.stage
    local pct = boss.hp / boss.max_hp
    for i, threshold in ipairs(boss.stage_thresholds) do
        local target_stage = i + 1
        if pct <= threshold and boss.stage < target_stage then
            boss.stage = target_stage
        end
    end
    return {
        stage_changed = boss.stage ~= old_stage,
        new_stage     = boss.stage,
        defeated      = boss.hp <= 0,
    }
end

function Bosses.count()
    return #ROSTER
end

return Bosses
