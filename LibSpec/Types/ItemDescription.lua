-------------------------------------------------------------------------------
-- @module ItemDescription

--- @type ItemDescription
-- @field #number abilityId id of ability (if is of type ability_module)
-- @field #table attributes table of attributes
-- @field #table certifications ???
-- @field #table classes table of strings of applicable classes
-- @field #table constraints cpu,power,weight
-- @field #string description description
-- @field #table flags id ???
-- @field #number iconId id of icon, not always present
-- @field #number level seems to be 0 or 1 for everything...
-- @field #string moduleType short description (if it's an ability_module), not always present
-- @field #string name short description/title of item
-- @field #number powerLevel ???
-- @field #string quality "common", "uncommon", etc.
-- @field #table tier level,description,name
-- @field #string type "consumable", "ability_module"
-- @field #string web_icon URL of image
ItemDescription = {}

--- @type ItemDescriptionFlags
-- @field #boolean tradable
-- @field #boolean is_salvageable
ItemDescriptionFlags = {}