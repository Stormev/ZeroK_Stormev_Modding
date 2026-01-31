return { chickend = {
  name                          = [[Chicken Tube]],
  description                   = [[Defence and energy source]],
  activateWhenBuilt             = true,
  builder                       = true,
  buildDistance       = 240,
  buildingGroundDecalDecaySpeed = 30,
  autoHeal            = 5,
  buildingGroundDecalSizeX      = 5,
  buildingGroundDecalSizeY      = 5,
  buildingGroundDecalType       = [[chickend_aoplane.dds]],
  buildPic                      = [[chickend.png]],
  category                      = [[FLOAT UNARMED]],

  customParams                  = {
    like_structure   = 1,
    select_show_eco  = 1,
  },

  buildoptions        = {
    [[chicken_drone]],
    [[chicken]],
    [[chicken_pigeon]],
    [[chicken_roc]],
    [[chickenf]],
    [[chicken_blimpy]],
  },

  canGuard                      = true,
  canMove                       = false,
  canPatrol                     = true,
  cantBeTransported             = true,

  energyMake                    = 4,
  explodeAs                     = [[NOWEAPON]],
  floater                       = true,
  footprintX                    = 3,
  footprintZ                    = 3,
  health                        = 800,
  iconType                      = [[defense]],
  idleAutoHeal                  = 20,
  idleTime                      = 300,
  levelGround                   = false,
  maxSlope                      = 36,
  maxWaterDepth                 = 20,
  metalCost                     = 120,
  energyCost                    = 120,
  buildTime                     = 120,
  noAutoFire                    = false,
  noChaseCategory               = [[FIXEDWING LAND SHIP SATELLITE SWIM GUNSHIP SUB HOVER]],
  objectName                    = [[tube.s3o]],
  onoffable                     = true,
  power                         = 120,
  reclaimable                   = false,
  script                        = [[chickend.lua]],
  selfDestructAs                = [[NOWEAPON]],

  sfxtypes                      = {

    explosiongenerators = {
      [[custom:blood_spray]],
      [[custom:blood_explode]],
      [[custom:dirt]],
    },

  },
  sightDistance                 = 512,
  sonarDistance                 = 512,
  upright                       = false,
  useBuildingGroundDecal        = true,
  workerTime                    = 5,
  yardMap                       = [[ooooooooo]],

  weapons                       = {

    {
      def                = [[SPORES]],
      onlyTargetCategory = [[FIXEDWING LAND SINK TURRET SHIP SWIM FLOAT GUNSHIP HOVER]],
    },

  },


  weaponDefs                    = {

    SPORES = {
      name                    = [[Explosive Spores]],
      areaOfEffect            = 96,
      avoidFriendly           = false,
      burst                   = 4,
      burstrate               = 0.2,
      collideFriendly         = false,
      craterBoost             = 0,
      craterMult              = 0,
      
      customParams            = {
        light_radius = 0,
      },
      
      damage                  = {
        default = 70,
        planes  = 70,
      },

      dance                   = 60,
      explosionGenerator      = [[custom:RED_GOO]],
      fireStarter             = 0,
      flightTime              = 5,
      groundbounce            = 1,
      heightmod               = 0.5,
      impulseBoost            = 0,
      impulseFactor           = 0.4,
      interceptedByShieldType = 2,
      model                   = [[chickeneggyellow.s3o]],
      range                   = 670,
      reloadtime              = 8,
      smokeTrail              = true,
      startVelocity           = 100,
      texture1                = [[]],
      texture2                = [[sporetrail]],
      tolerance               = 10000,
      tracks                  = true,
      trajectoryHeight        = 2,
      turnRate                = 24000,
      turret                  = true,
      waterweapon             = true,
      weaponAcceleration      = 100,
      weaponType              = [[MissileLauncher]],
      weaponVelocity          = 500,
      wobble                  = 32000,
    },

  },

} }