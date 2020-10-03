#include <cstdio>
#include <assert.h>
#include <iostream>
using namespace std;
#include "vops.h"
#include "autumnParticles.h"
namespace ANONYMOUS{

template<typename T_0>
Particle* Particle::create(Position*  origin_, bool  alive_, T_0* render_, int render_len){
  int tlen_render = 20; 
  void* temp= malloc( sizeof(Particle)   + sizeof(Cell* )*tlen_render); 
  Particle* rv = new (temp)Particle();
  rv->origin =  origin_;
  rv->alive =  alive_;
  CopyArr(rv->render, render_, tlen_render, render_len ); 
  rv->type= Object::PARTICLE_type;
  return rv;
}
Position* Position::create(int  x_, int  y_){
  void* temp= malloc( sizeof(Position)  ); 
  Position* rv = new (temp)Position();
  rv->x =  x_;
  rv->y =  y_;
  return rv;
}
Click* Click::create(Position*  position_){
  void* temp= malloc( sizeof(Click)  ); 
  Click* rv = new (temp)Click();
  rv->position =  position_;
  return rv;
}
template<typename T_0>
Cell* Cell::create(Position*  position_, T_0* color_, int color_len){
  int tlen_color = 20; 
  void* temp= malloc( sizeof(Cell)   + sizeof(char )*tlen_color); 
  Cell* rv = new (temp)Cell();
  rv->position =  position_;
  CopyArr(rv->color, color_, tlen_color, color_len ); 
  return rv;
}
template<typename T_0, typename T_1>
Scene* Scene::create(T_0* objects_, int objects_len, T_1* background_, int background_len){
  int tlen_objects = 20; 
  int tlen_background = 20; 
  void* temp= malloc( sizeof(Scene)   + sizeof(Particle* )*tlen_objects + sizeof(char )*tlen_background); 
  Scene* rv = new (temp)Scene();
  rv->objects= (Particle** ) (((char*)&(rv->background))   + sizeof(char )*tlen_background); 
  CopyArr(rv->objects, objects_, tlen_objects, objects_len ); 
  CopyArr(rv->background, background_, tlen_background, background_len ); 
  return rv;
}
template<typename T_0, typename T_1>
State* State::create(int  time_, T_0* clickHistory_, int clickHistory_len, T_1* particlesHistory_, int particlesHistory_len, Scene*  scene_){
  int tlen_clickHistory = 20; 
  int tlen_particlesHistory = 20 * 20; 
  void* temp= malloc( sizeof(State)   + sizeof(Click* )*tlen_clickHistory + sizeof(Particle* )*tlen_particlesHistory); 
  State* rv = new (temp)State();
  rv->time =  time_;
  rv->scene =  scene_;
  rv->clickHistory= (Click** ) (((char*)&(rv->particlesHistory))   + sizeof(Particle* )*tlen_particlesHistory); 
  CopyArr(rv->clickHistory, clickHistory_, tlen_clickHistory, clickHistory_len ); 
  CopyArr(rv->particlesHistory, particlesHistory_, tlen_particlesHistory, particlesHistory_len ); 
  return rv;
}
void addParticle1__Wrapper() {
  int  uniformChoiceCounter__ANONYMOUS_s60=0;
  glblInit_uniformChoiceCounter__ANONYMOUS_s65(uniformChoiceCounter__ANONYMOUS_s60);
  addParticle1(uniformChoiceCounter__ANONYMOUS_s60);
}
void addParticle1__WrapperNospec() {}
void glblInit_uniformChoiceCounter__ANONYMOUS_s65(int& uniformChoiceCounter__ANONYMOUS_s64) {
  uniformChoiceCounter__ANONYMOUS_s64 = 0;
}
void addParticle1(int& uniformChoiceCounter__ANONYMOUS_s58) {
  State*  state_s9=NULL;
  init(state_s9);
  State*  state_s11=NULL;
  synthNext(state_s9, Click::create(Position::create(1, 1)), state_s11, uniformChoiceCounter__ANONYMOUS_s58);
  void * _tt0[20] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
  Cell**  renderedScene_s13= new Cell* [20]; CopyArr<Cell* >(renderedScene_s13,_tt0, 20, 20);
  renderScene(state_s11->scene, renderedScene_s13);
  assert (((renderedScene_s13[0])) != (NULL));;
  assert ((((renderedScene_s13[0])->position->x) == (1)) && (((renderedScene_s13[0])->position->y) == (1)));;
  delete[] renderedScene_s13;
}
void init(State*& _out) {
  _out = State::create(0, (Click**)NULL, 0, (Particle**)NULL, 0, NULL);
  _out->time = 0;
  (_out->clickHistory[0]) = NULL;
  void * _tt1[20] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
  Particle**  particles= new Particle* [20]; CopyArr<Particle* >(particles,_tt1, 20, 20);
  CopyArr<Particle* >((_out->particlesHistory+ 0),particles, 20, 20);
  char _tt2[12] = {'t', 'r', 'a', 'n', 's', 'p', 'a', 'r', 'e', 'n', 't', '\0'};
  _out->scene = Scene::create(particles, 20, _tt2, 12);
  delete[] particles;
  return;
}
void synthNext(State* state, Click* click, State*& _out, int& uniformChoiceCounter__ANONYMOUS_s62) {
  Particle**  particles= new Particle* [20]; CopyArr<Particle* >(particles,NULL, 20);
  assert (((state->time) >= (0)) && ((state->time) < (20)));;
  CopyArr<Particle* >(particles,(state->particlesHistory+ 20 * state->time), 20, 20);
  Position*  clickPosition=click->position;
  if ((click) != (NULL)) {
    Particle*  particles_s17=NULL;
    particle(clickPosition, particles_s17);
    void * _tt3[20] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    Particle**  particles_s19= new Particle* [20]; CopyArr<Particle* >(particles_s19,_tt3, 20, 20);
    Particle* * _tt4= new Particle* [20]; 
    CopyArr<Particle*>(_tt4,particles, 20, 20);
    addObj(_tt4, particles_s17, particles_s19);
    CopyArr<Particle* >(particles,particles_s19, 20, 20);
  }
  if ((click) == (NULL)) {
    void * _tt5[20] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    Particle**  particles_s21= new Particle* [20]; CopyArr<Particle* >(particles_s21,_tt5, 20, 20);
    Particle* * _tt6= new Particle* [20]; 
    CopyArr<Particle*>(_tt6,particles, 20, 20);
    updateObjArray_lam_s01(_tt6, particles_s21, uniformChoiceCounter__ANONYMOUS_s62);
    CopyArr<Particle* >(particles,particles_s21, 20, 20);
  }
  state->time = state->time + 1;
  (state->clickHistory[state->time]) = click;
  assert (((state->time) >= (0)) && ((state->time) < (20)));;
  CopyArr<Particle* >((state->particlesHistory+ 20 * state->time),particles, 20, 20);
  char _tt7[12] = {'t', 'r', 'a', 'n', 's', 'p', 'a', 'r', 'e', 'n', 't', '\0'};
  state->scene = Scene::create(particles, 20, _tt7, 12);
  _out = state;
  delete[] particles;
  return;
}
void renderScene(Scene* scene, Cell** _out/* len = 20 */) {
  CopyArr<Cell* >(_out,NULL, 20);
  int  cellIndex=0;
  for (int  objIndex=0;(objIndex) < (20);objIndex = objIndex + 1){
    Particle*  obj=NULL;
    obj = (scene->objects[objIndex]);
    if ((obj) != (NULL)) {
      void * _tt8[20] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
      Cell**  objCells_s15= new Cell* [20]; CopyArr<Cell* >(objCells_s15,_tt8, 20, 20);
      renderObj(obj, objCells_s15);
      for (int  objCellIndex=0;(objCellIndex) < (20);objCellIndex = objCellIndex + 1){
        int  uo_s4=cellIndex;
        cellIndex = cellIndex + 1;
        (_out[uo_s4]) = (objCells_s15[objCellIndex]);
      }
      delete[] objCells_s15;
    }
  }
  return;
}
void particle(Position* origin, Particle*& _out) {
  char _tt10[5] = {'b', 'l', 'u', 'e', '\0'};
  Cell* _tt9[1] = {Cell::create(Position::create(0, 0), _tt10, 5)};
  _out = Particle::create(origin, 1, _tt9, 1);
  return;
}
void addObj(Particle** objects/* len = 20 */, Particle* object, Particle** _out/* len = 20 */) {
  CopyArr<Particle* >(_out,objects, 20, 20);
  for (int  i=0;(i) < (20);i = i + 1){
    if (((_out[i])) == (NULL)) {
      (_out[i]) = object;
      return;
    }
  }
  return;
}
void updateObjArray_lam_s01(Particle** objects/* len = 20 */, Particle** _out/* len = 20 */, int& uniformChoiceCounter__ANONYMOUS_s61) {
  CopyArr<Particle* >(_out,NULL, 20);
  for (int  i=0;(i) < (20);i = i + 1){
    if (((objects[i])) != (NULL)) {
      Particle*  obj=(objects[i]);
      void * _tt11[20] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
      Position**  _out_s51= new Position* [20]; CopyArr<Position* >(_out_s51,_tt11, 20, 20);
      adjPositions(16, obj->origin, _out_s51);
      Position*  _out_s53=NULL;
      Position* * _tt12= new Position* [20]; 
      CopyArr<Position*>(_tt12,_out_s51, 20, 20);
      uniformChoice(uniformChoiceCounter__ANONYMOUS_s61, _tt12, _out_s53);
      Particle*  _out_s55=NULL;
      particle(_out_s53, _out_s55);
      (_out[i]) = _out_s55;
    } else {
      (_out[i]) = (objects[i]);
    }
  }
  return;
}
void renderObj(Particle* object, Cell** _out/* len = 20 */) {
  CopyArr<Cell* >(_out,NULL, 20);
  for (int  i=0;(i) < (20);i = i + 1){
    Cell*  cell=(object->render[i]);
    if ((cell) != (NULL)) {
      (_out[i]) = Cell::create(Position::create(cell->position->x + object->origin->x, cell->position->y + object->origin->y), cell->color, 20);
    }
  }
  return;
}
void adjPositions(int gridSize, Position* position, Position** _out/* len = 20 */) {
  int  x=0;
  x = position->x;
  int  y=0;
  y = position->y;
  Position* _tt13[4] = {Position::create(x + 1, y), Position::create(x - 1, y), Position::create(x, y - 1), Position::create(x, y + 1)};
  CopyArr<Position* >(_out,_tt13, 20, 4);
  void * _tt14[4] = {NULL, NULL, NULL, NULL};
  Position**  retVal= new Position* [4]; CopyArr<Position* >(retVal,_tt14, 4, 4);
  int  retIndex=0;
  for (int  i=0;(i) < (20);i = i + 1){
    bool  _out_s23=0;
    isWithinBoundsPosition(gridSize, (_out[i]), _out_s23);
    if (_out_s23) {
      int  uo_s5=retIndex;
      retIndex = retIndex + 1;
      (retVal[uo_s5]) = (_out[i]);
    }
  }
  delete[] retVal;
  return;
}
void uniformChoice(int& counter, Position** positions/* len = 20 */, Position*& _out) {
  _out = (positions[counter % 4]);
  counter = counter + 1;
  return;
}
void isWithinBoundsPosition(int gridSize, Position* position, bool& _out) {
  int  num=(gridSize * position->x) + position->y;
  if (((num) >= (0)) && ((num) < ((gridSize * gridSize)))) {
    _out = 1;
    return;
  } else {
    _out = 0;
    return;
  }
}

}
