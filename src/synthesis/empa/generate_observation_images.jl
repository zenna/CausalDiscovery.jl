using Autumn
include("scene.jl")
include("construct_observation_data.jl")

"""
USAGE: particles  

a = parseautumn(" particles program from interface ")
mod = eval(compiletojulia(a))
observations, _ = generate_observations_particles(mod)
images = convert_render_output_to_image_seq(observations)

For other models, replace particles program string and replace generate_observations_particles
with one of the other generate_observations_[model name] in "construct_observation_data."

"""

function convert_render_output_to_image_seq(render_output, grid_size = 16)
  map(r -> convert_render_output_to_image(r, grid_size), render_output)
end

function convert_render_output_to_image(render_output, grid_size = 16)
  image = [RGBA(1.0, 0.0, 0.0, 1.0) for x in 1:grid_size, y in 1:grid_size]

  for cell in render_output 
    color = rgb(cell.color)
    image[cell.position.y, cell.position.x] = RGBA(color.r, color.g, color.b, 1.0) # 0.6
  end
  image 
end

# function particles_images(mod::Module)
#   observations, _ = generate_observations_particles(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function ice_images(mod::Module)
#   observations, _ = generate_observations_ice(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function ants_images(mod::Module)
#   a = au"""(program
#   (= GRID_SIZE 16)
  
#   (object Ant (Cell 0 0 "gray"))
#   (object Food (Cell 0 0 "red"))

#   (: ants (List Ant))
#   (= ants (initnext (map Ant (randomPositions GRID_SIZE 6)) 
#                     (updateObj (prev ants) (--> obj (move obj (unitVector obj (closest obj Food)))))))

#   (: foods (List Food))
#   (= foods (initnext (list) 
#                      (updateObj (prev foods) (--> obj (if (intersects obj ants)
#                                                        then (removeObj obj)
#                                                        else obj)))))
  
#   (on clicked (= foods (addObj (prev foods) (map Food (randomPositions GRID_SIZE 4)))))
# )"""

#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_ants(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function space_invaders_images(mod::Module)
#   a = au"""(program
#   (= GRID_SIZE 16)
  
#   (object Enemy (Cell 0 0 "blue"))
#   (object Hero (Cell 0 0 "black"))
#   (object Bullet (Cell 0 0 "red"))
#   (object EnemyBullet (Cell 0 0 "orange"))
  
#   (: enemies1 (List Enemy))
#   (= enemies1 (initnext (mapPositions 
#                           Enemy 
#                           GRID_SIZE
#                           (--> pos (& (== (.. pos y) 1) (== (% (.. pos x) 2) 0
#                                                             )))) 
#                         (prev enemies1)))

#   (: enemies2 (List Enemy))
#   (= enemies2 (initnext (mapPositions 
#                           Enemy 
#                           GRID_SIZE
#                           (--> pos (& (== (.. pos y) 3) (== (% (.. pos x) 2) 1
#                                                             )))) 
#                         (prev enemies2)))

  
#   (: hero Hero)
#   (= hero (initnext (Hero (Position 8 15)) (prev hero)))
  
#   (: enemyBullets (List EnemyBullet))
#   (= enemyBullets (initnext (list) (updateObj (prev enemyBullets) (--> obj (move obj 0 1)))))

#   (: bullets (List Bullet))
#   (= bullets (initnext (list) (updateObj (prev bullets) (--> obj (move obj 0 -1)))))
  
#   (: time Int)
#   (= time (initnext 0 (+ (prev time) 1)))                                                         
                                                           
#   (on left (= hero (moveLeftNoCollision (prev hero))))
#   (on right (= hero (moveRightNoCollision (prev hero))))
#   (on (& up (.. (prev hero) alive)) (= bullets (addObj (prev bullets) (Bullet (.. (prev hero) origin)))))  

#   (on (== (% time 10) 5) (= enemies1 (updateObj (prev enemies1) (--> obj (moveLeft obj)))))
#   (on (== (% time 10) 0) (= enemies1 (updateObj (prev enemies1) (--> obj (moveRight obj)))))

#   (on (== (% time 10) 5) (= enemies2 (updateObj (prev enemies2) (--> obj (moveRight obj)))))
#   (on (== (% time 10) 0) (= enemies2 (updateObj (prev enemies2) (--> obj (moveLeft obj)))))
  
#   (on (intersects (prev bullets) (prev enemies1))
#   	(let ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemies1)))))
#           (= enemies1 (removeObj (prev enemies1) (--> obj (intersects obj (prev bullets)))))))
#   )          
           
#   (on (intersects (prev bullets) (prev enemies2))
#   	(let ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemies2)))))
#           (= enemies2 (removeObj (prev enemies2) (--> obj (intersects obj (prev bullets)))))))
#   )
          
#   (on (== (% time 5) 2) (= enemyBullets (addObj (prev enemyBullets) (EnemyBullet (uniformChoice (map (--> obj (.. obj origin)) (prev enemies2)))))))         
#   (on (intersects (prev hero) (prev enemyBullets)) (= hero (removeObj (prev hero))))

#   (on (intersects (prev bullets) (prev enemyBullets)) 
#     (let 
#        ((= bullets (removeObj (prev bullets) (--> obj (intersects obj (prev enemyBullets))))) 
#         (= enemyBullets (removeObj (prev enemyBullets) (--> obj (intersects obj (prev bullets))))))))           
# )"""

#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_space_invaders(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function disease_images(mod::Module) 
#   a = """(program
#   (= GRID_SIZE 16)
  
#   (object Particle (: health Bool) (Cell 0 0 (if health then "gray" else "darkgreen")))

#   (: inactiveParticles (List Particle))
#   (= inactiveParticles (initnext (list (Particle true (Position 5 3)) (Particle true (Position 11 14)) (Particle true (Position 4 8)) (Particle true (Position 9 9)) (Particle true (Position 1 13)) (Particle true (Position 14 5)))  
#                        (updateObj (prev inactiveParticles) (--> obj (if (! (.. activeParticle health))
#                                                                      then (updateObj obj "health" false)
#                                                                      else obj)) 
# 														   (--> obj (adjacent (.. obj origin) (.. (prev activeParticle) origin))))))   

#   (: activeParticle Particle)
#   (= activeParticle (initnext (Particle false (Position 0 0)) (prev activeParticle))) 

#   (on (!= (length (filter (--> obj (! (.. obj health))) (adjacentObjs activeParticle))) 0) (= activeParticle (updateObj (prev activeParticle) "health" false)))
#   (on (clicked (prev inactiveParticles)) 
#       (let ((= inactiveParticles (addObj (prev inactiveParticles) (prev activeParticle))) 
#             (= activeParticle (objClicked click (prev inactiveParticles)))
#             (= inactiveParticles (removeObj inactiveParticles (objClicked click (prev inactiveParticles))))
#            )))
#   (on left (= activeParticle (moveNoCollision (prev activeParticle) -1 0)))
#   (on right (= activeParticle (moveNoCollision (prev activeParticle) 1 0)))
#   (on up (= activeParticle (moveNoCollision (prev activeParticle) 0 -1)))
#   (on down (= activeParticle (moveNoCollision (prev activeParticle) 0 1)))
# )"""
#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_disease(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function water_plug_images(mod::Module)
#   a = """(program
#   (= GRID_SIZE 16)

#   (object Button (: color String) (Cell 0 0 color))
#   (object Vessel (Cell 0 0 "purple"))
#   (object Plug (Cell 0 0 "orange"))
#   (object Water (Cell 0 0 "blue"))

#   (: vesselButton Button)
#   (= vesselButton (Button "purple" (Position 2 0)))
#   (: plugButton Button)
#   (= plugButton (Button "orange" (Position 5 0)))
#   (: waterButton Button)
#   (= waterButton (Button "blue" (Position 8 0)))
#   (: removeButton Button)
#   (= removeButton (Button "black" (Position 11 0)))
#   (: clearButton Button)
#   (= clearButton (Button "red" (Position 14 0)))

#   (: vessels (List Vessel))
#   (= vessels (initnext (list (Vessel (Position 6 15)) (Vessel (Position 6 14)) (Vessel (Position 6 13)) (Vessel (Position 5 12)) (Vessel (Position 4 11)) (Vessel (Position 3 10)) (Vessel (Position 9 15)) (Vessel (Position 9 14)) (Vessel (Position 9 13)) (Vessel (Position 10 12)) (Vessel (Position 11 11)) (Vessel (Position 12 10))) (prev vessels)))
#   (: plugs (List Plug))
#   (= plugs (initnext (list (Plug (Position 7 15)) (Plug (Position 8 15)) (Plug (Position 7 14)) (Plug (Position 8 14)) (Plug (Position 7 13)) (Plug (Position 8 13))) (prev plugs)))
#   (: water (List Water))
#   (= water (initnext (list) (updateObj (prev water) nextLiquid)))

#   (= currentParticle (initnext "vessel" (prev currentParticle)))

#   (on (& clicked (& (isFree click) (== currentParticle "vessel"))) (= vessels (addObj (prev vessels) (Vessel (Position (.. click x) (.. click y))))))
#   (on (& clicked (& (isFree click) (== currentParticle "plug"))) (= plugs (addObj (prev plugs) (Plug (Position (.. click x) (.. click y))))))
#   (on (& clicked (& (isFree click) (== currentParticle "water"))) (= water (addObj (prev water) (Water (Position (.. click x) (.. click y))))))
#   (on (clicked vesselButton) (= currentParticle "vessel"))
#   (on (clicked plugButton) (= currentParticle "plug"))
#   (on (clicked waterButton) (= currentParticle "water"))
#   (on (clicked removeButton) (= plugs (removeObj plugs (--> obj true))))
#   (on (clicked clearButton) (let ((= vessels (removeObj vessels (--> obj true))) (= plugs (removeObj plugs (--> obj true))) (= water (removeObj water (--> obj true))))))  
# )"""
#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_water_plug(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function paint_images(mod::Module)
#   a = """(program
#   (= GRID_SIZE 16)
  
#   (object Particle (: color String) (Cell 0 0 color))

#   (: particles (List Particle))
#   (= particles (initnext (list) (prev particles)))
  
#   (: currColor String)
#   (= currColor (initnext "red" (prev currColor)))
  
#   (on (& clicked (isFree click)) (= particles (addObj (prev particles) (Particle currColor (Position (.. click x) (.. click y))))))
#   (on (& up (== (prev currColor) "red")) (= currColor "gold"))
#   (on (& up (== (prev currColor) "gold")) (= currColor "green"))
#   (on (& up (== (prev currColor) "green")) (= currColor "blue"))
#   (on (& up (== (prev currColor) "blue")) (= currColor "purple"))
#   (on (& up (== (prev currColor) "purple")) (= currColor "red"))
# )"""
#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_paint(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function gravity_images(mod::Module)
#   a = """(program
#   (= GRID_SIZE 16)
#   (= background "black")
    
#   (object Button (: color String) (Cell 0 0 color))
#   (object Blob (list (Cell 0 0 "blue") (Cell 0 1 "blue") (Cell 1 0 "blue") (Cell 1 1 "blue")))

#   (: leftButton Button)
#   (= leftButton (initnext (Button "red" (Position 0 7)) (prev leftButton)))
  
#   (: rightButton Button)
#   (= rightButton (initnext (Button "darkorange" (Position 15 7)) (prev rightButton)))
    
#   (: upButton Button)
#   (= upButton (initnext (Button "gold" (Position 7 0)) (prev upButton)))
  
#   (: downButton Button)
#   (= downButton (initnext (Button "green" (Position 7 15)) (prev downButton)))
  
#   (: blobs (List Blob))
#   (= blobs (initnext (list) (prev blobs)))
  
#   (: gravity String)
#   (= gravity (initnext "down" (prev gravity)))
  
#   (on (== gravity "left") (= blobs (updateObj (prev blobs) (--> obj (moveLeftNoCollision obj)))))
#   (on (== gravity "right") (= blobs (updateObj (prev blobs) (--> obj (moveRightNoCollision obj)))))
#   (on (== gravity "up") (= blobs (updateObj (prev blobs) (--> obj (moveUpNoCollision obj)))))
#   (on (== gravity "down") (= blobs (updateObj (prev blobs) (--> obj (moveDownNoCollision obj)))))
  
#   (on (& clicked (isFree click)) (= blobs (addObj (prev blobs) (Blob (Position (.. click x) (.. click y))))) )
  
#   (on (clicked leftButton) (= gravity "left"))

#   (on (clicked rightButton) (= gravity "right"))

#   (on (clicked upButton) (= gravity "up"))

#   (on (clicked downButton) (= gravity "down"))
# )"""
#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_gravity(mod)
#   images = convert_render_output_to_image_seq(observations)
# end

# function sand_images(mod::Module)
#   a = """(program
#   (= GRID_SIZE 16)
  
#   (object Button (: color String) (Cell 0 0 color))
#   (object Sand (: liquid Bool) (Cell 0 0 (if liquid then "sandybrown" else "tan")))
#   (object Water (Cell 0 0 "skyblue"))
  
#   (: sandButton Button)
#   (= sandButton (initnext (Button "tan" (Position 2 0)) (prev sandButton)))
  
#   (: waterButton Button)
#   (= waterButton (initnext (Button "skyblue" (Position 7 0)) (prev waterButton)))
  
#   (: sand (List Sand))
#   (= sand (initnext (list) 
#             (updateObj (prev sand) (--> obj (if (.. obj liquid) 
# 											 then (nextLiquid obj)
# 											 else (nextSolid obj))))))
  
#   (: water (List Water))
#   (= water (initnext (list) (updateObj (prev water) (--> obj (nextLiquid obj)))))
  
    
#   (: clickType String)
#   (= clickType (initnext "sand" (prev clickType)))
  
#   (on true (= sand (updateObj (prev sand) (--> obj (updateObj obj "liquid" true)) (--> obj (& (! (.. obj liquid)) (intersects (adjacentObjs obj) (prev water)))))))
  
#   (on (clicked sandButton) (= clickType "sand"))
#   (on (clicked waterButton) (= clickType "water"))
#   (on (& (& clicked (isFree click)) (== clickType "sand"))  (= sand (addObj sand (Sand false (Position (.. click x) (.. click y))))))
#   (on (& (& clicked (isFree click)) (== clickType "water")) (= water (addObj water (Water (Position (.. click x) (.. click y))))))

# )"""
#   global mod = eval(compiletojulia(a))
#   observations, _ = generate_observations_sand_simple(mod)
#   images = convert_render_output_to_image_seq(observations, 16)
# end