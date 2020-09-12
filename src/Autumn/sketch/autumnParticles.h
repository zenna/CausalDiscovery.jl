#ifndef AUTUMNPARTICLES_H
#define AUTUMNPARTICLES_H

#include <cstring>

#include "vops.h"

namespace ANONYMOUS{
class Particle; 
class Object; 
class Position; 
class Click; 
class Cell; 
class Scene; 
class State; 
}
namespace ANONYMOUS{
class Particle; 
class Object; 
class Position; 
class Click; 
class Cell; 
class Scene; 
class State; 
class Particle : public Object{
  public:
  Position*  origin;
  bool  alive;
  Cell*  render[];
  Particle(){}
template<typename T_0>
  static Particle* create(  Position*  origin_,   bool  alive_,   T_0* render_, int render_len);
  ~Particle(){
  }
  void operator delete(void* p){ free(p); }
};
class Object{
  public:
  typedef enum {PARTICLE_type} _kind;
  _kind type;
  ~Object(){
  }
  void operator delete(void* p){ free(p); }
};
class Position{
  public:
  int  x;
  int  y;
  Position(){}
  static Position* create(  int  x_,   int  y_);
  ~Position(){
  }
  void operator delete(void* p){ free(p); }
};
class Click{
  public:
  Position*  position;
  Click(){}
  static Click* create(  Position*  position_);
  ~Click(){
  }
  void operator delete(void* p){ free(p); }
};
class Cell{
  public:
  Position*  position;
  char  color[];
  Cell(){}
template<typename T_0>
  static Cell* create(  Position*  position_,   T_0* color_, int color_len);
  ~Cell(){
  }
  void operator delete(void* p){ free(p); }
};
class Scene{
  public:
  Particle**  objects;
  char  background[];
  Scene(){}
template<typename T_0, typename T_1>
  static Scene* create(  T_0* objects_, int objects_len,   T_1* background_, int background_len);
  ~Scene(){
  }
  void operator delete(void* p){ free(p); }
};
class State{
  public:
  int  time;
  Scene*  scene;
  Click**  clickHistory;
  Particle*  particlesHistory[];
  State(){}
template<typename T_0, typename T_1>
  static State* create(  int  time_,   T_0* clickHistory_, int clickHistory_len,   T_1* particlesHistory_, int particlesHistory_len,   Scene*  scene_);
  ~State(){
  }
  void operator delete(void* p){ free(p); }
};
extern void addParticle1__Wrapper();
extern void addParticle1__WrapperNospec();
extern void glblInit_uniformChoiceCounter__ANONYMOUS_s65(int& uniformChoiceCounter__ANONYMOUS_s64);
extern void addParticle1(int& uniformChoiceCounter__ANONYMOUS_s58);
extern void init(State*& _out);
extern void synthNext(State* state, Click* click, State*& _out, int& uniformChoiceCounter__ANONYMOUS_s62);
extern void renderScene(Scene* scene, Cell** _out/* len = 20 */);
extern void particle(Position* origin, Particle*& _out);
extern void addObj(Particle** objects/* len = 20 */, Particle* object, Particle** _out/* len = 20 */);
extern void updateObjArray_lam_s01(Particle** objects/* len = 20 */, Particle** _out/* len = 20 */, int& uniformChoiceCounter__ANONYMOUS_s61);
extern void renderObj(Particle* object, Cell** _out/* len = 20 */);
extern void adjPositions(int gridSize, Position* position, Position** _out/* len = 20 */);
extern void uniformChoice(int& counter, Position** positions/* len = 20 */, Position*& _out);
extern void isWithinBoundsPosition(int gridSize, Position* position, bool& _out);
}

#endif
