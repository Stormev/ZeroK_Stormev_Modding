return { roost = {
  name = [[Roost]],
  description = [[Spawns Chicken]],
  
  builder = true,
  canMove = false,
  isBuilding = true,
  
  buildDistance = 320,
  workerTime = 10,
  
  buildoptions = {
    [[chicken_drone]],
    [[chicken]],
    [[chicken_leaper]],
    [[chickena]],
    [[chickens]],
    [[chickenc]],
    [[chickenr]],
    [[chickenblobber]],
    [[chicken_spidermonkey]],
    [[chicken_sporeshooter]],
    [[chickenwurm]],
    [[chicken_dodo]],
    [[chicken_shield]],
    [[chicken_tiamat]],
    [[chicken_pigeon]],
    [[chickenf]],
    [[chicken_blimpy]],
    [[chicken_dragon]],
  },
  
  energyMake        = 0,
  explodeAs         = [[NOWEAPON]],
  footprintX        = 3,
  footprintZ        = 3,
  health            = 1800,
  iconType          = [[special]],
  idleAutoHeal      = 20,
  idleTime          = 300,
  levelGround       = false,
  maxSlope          = 36,
  metalCost         = 340,
  metalMake         = 2.5,
  noAutoFire        = false,
  objectName        = [[roost.s3o]],
  script            = [[roost.lua]],
  selfDestructAs    = [[NOWEAPON]],

  sfxtypes          = {

    explosiongenerators = {
      [[custom:dirt2]],
      [[custom:dirt3]],
    },

  },

  sightDistance     = 273,
  upright           = false,
  waterline         = 0,
  workerTime        = 8,

  customParams = {
    like_structure = 1,
  },

  weapons           = {

    {
      def                = [[AEROSPORES]],
      onlyTargetCategory = [[FIXEDWING GUNSHIP]],
    },

  },


  weaponDefs        = {

    AEROSPORES = {
      name                    = [[Anti-Air Spores]],
      areaOfEffect            = 24,
      avoidFriendly           = false,
      burst                   = 4,
      burstrate               = 0.2,
      canAttackGround         = false,
      collideFriendly         = false,
      craterBoost             = 0,
      craterMult              = 0,
      
      customParams            = {
        light_radius = 0,
      },
      
      damage                  = {
        default = 80,
        planes  = 80,
      },

      dance                   = 60,
      explosionGenerator      = [[custom:NONE]],
      fireStarter             = 0,
      fixedlauncher           = 1,
      flightTime              = 5,
      groundbounce            = 1,
      heightmod               = 0.5,
      impactOnly              = true,
      impulseBoost            = 0,
      impulseFactor           = 0.4,
      interceptedByShieldType = 2,
      model                   = [[chickeneggblue.s3o]],
      range                   = 600,
      reloadtime              = 3,
      smokeTrail              = true,
      startVelocity           = 100,
      texture1                = [[]],
      texture2                = [[sporetrailblue]],
      tolerance               = 10000,
      tracks                  = true,
      turnRate                = 24000,
      turret                  = true,
      waterweapon             = true,
      weaponAcceleration      = 100,
      weaponType              = [[MissileLauncher]],
      weaponVelocity          = 500,
      wobble                  = 32000,
    },

  },


  featureDefs       = {
  },
}}