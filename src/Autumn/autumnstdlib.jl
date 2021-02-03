module AutumnStandardLibrary
export library

library = """
int uniformChoiceCounter = 0;
Position uniformChoice(ref int counter, Position[ARR_BND] positions) {
  Position position;
  if (positions[4] == null) {
    position = positions[counter % 3];
  } else {
    position = positions[counter % 4];
  }
  counter++;
  return position;
}

Object[ARR_BND] flattenSceneObjects(Object[ARR_BND][ARR_BND] nestedObjects) {
  Object[ARR_BND] objects;
  int topIndex = 0;
  for (int objArrIndex = 0; objArrIndex < ARR_BND; objArrIndex++) {
    Object[ARR_BND] objArr = nestedObjects[objArrIndex];
    for (int objIndex = 0; objIndex < ARR_BND; objIndex++) {
      Object obj = objArr[objIndex];
      if (obj != null) {
        if (topIndex < ARR_BND) {
          objects[topIndex++] = obj;
        } else {
          return objects;
        }
      }
    }
  }
  return objects;
}

struct Object {
  Position origin;
  bit alive;
  char[STR_BND] type;
  Cell[ARR_BND] render;
}

struct Position {
  int x;
  int y;
}

struct Click {
  Position position;
}
struct KeyPress {}
struct Left extends KeyPress {}
struct Right extends KeyPress {}
struct Up extends KeyPress {}
struct Down extends KeyPress {}

struct Cell {
  Position position;
  char[STR_BND] color;
}

struct Scene {
  Object[ARR_BND][ARR_BND] objects;
  char[STR_BND] background;
}

// render functions
Cell[ARR_BND] renderScene(Scene scene) {
  Cell[ARR_BND] cells;
  Cell[ARR_BND] objCells;
  int cellIndex = 0;

  for (int objIndex = 0; objIndex < ARR_BND; objIndex++) {
    Object obj = flattenSceneObjects(scene.objects)[objIndex];
    if (obj != null) {
      objCells = renderObj(obj);
      for (int objCellIndex = 0; objCellIndex < ARR_BND; objCellIndex++) {
        cells[cellIndex++] = objCells[objCellIndex];
      }
    }
  }
  return cells;
}

bit sceneEquals(Cell[ARR_BND] cells1, Cell[ARR_BND] cells2) {
  return true;
}

Cell[ARR_BND] renderObj(Object object) {
  Cell[ARR_BND] cells;
  for (int i = 0; i < ARR_BND; i++) {
    Cell cell = object.render[i];
    if (cell != null) {
      cells[i] = new Cell(position=new Position(x=cell.position.x+object.origin.x,
                                                y=cell.position.y+object.origin.y),
                          color=cell.color);
    }
  }
  return cells;
}

// is within bounds
bit isWithinBoundsPosition(Position position) {
  int num = GRID_SIZE * position.x + position.y;
  if (num >= 0 && num < GRID_SIZE * GRID_SIZE) {
    return true;
  } else {
    return false;
  }
}

bit isWithinBoundsObject(Object object) {
  Cell[ARR_BND] cells = renderObj(object);
  Cell cell;
  for (int cellIndex = 0; cellIndex < ARR_BND; cellIndex++) {
    cell = cells[cellIndex];
    if (cell == null) {
      return true;
    }
    if (!isWithinBoundsPosition(cell.position)) {
      return false;
    }
  }
  return true;
}

bit occurred(Click click) {
  if (click == null) {
    return false;
  } else {
    return true;
  }
}

// clicked
bit clickedObj(Click click, Object object) {
  Cell[ARR_BND] cells = renderObj(object);
  Cell cell;
  for (int cellIndex = 0; cellIndex < ARR_BND; cellIndex++ ) {
    if (cell == null) {
      return false;
    }

    if (clickedPosition(click, cell.position)) {
      return true;
    }
  }
  return false;
}

bit clickedObjArray(Click click, Object[ARR_BND] objects) {
  Object object;
  Cell cell;
  for (int objectIndex = 0; objectIndex < ARR_BND; objectIndex++) {
    object = objects[objectIndex];
    if (object == null) {
      return false;
    }

    if (clickedObj(click, object)) {
      return true;
    }
  }
  return false;
}

bit clickedPosition(Click click, Position position) {
  return (position.x == click.position.x) && (position.y == click.position.y);
}

// intersects NEW

bit intersectsObjObj(Object object1, Object object2) {
  Cell[ARR_BND] cells1 = renderObj(object1);
  Cell[ARR_BND] cells2 = renderObj(object2);
  Cell cell1;
  Cell cell2;
  for (int i = 0; i < ARR_BND; i++) {
    cell1 = cells1[i];
    for (int j = 0; j < ARR_BND; j++) {
      cell2 = cells2[j];
      if (cell1 != null && cell2 != null) {
        if (cell1.position.x == cell2.position.x && cell1.position.y == cell2.position.y) {
          return true;
        }
      }
    }
  }
  return false;
}

bit intersectsObjObjArray(Object object, Object[ARR_BND] objects) {
  for (int i = 0; i < ARR_BND; i++) {
    Object object2 = objects[i];
    if (intersectsObjObj(object, object2)) {
      return true;
    }
  }
  return false;
}


bit intersectsObjArrays(Object[ARR_BND] objects1, Object[ARR_BND] objects2) {
  for (int i = 0; i < ARR_BND; i++) {
    Object object1 = objects1[i];
    if (intersectsObjObjArray(object1, objects2)) {
      return true;
    }
  }
  return false;
}

bit intersectsScene(Scene scene, Object object) {
  Object[ARR_BND] objects = flattenSceneObjects(scene.objects);
  return intersectsObjObjArray(object, objects);
}

// add/remove/update objects
Object[ARR_BND] addObj(Object[ARR_BND] objects, Object object) {
  Object[ARR_BND] newObjects = objects;
  for (int i = 0; i < ARR_BND; i++) {
    if (newObjects[i] == null) {
      newObjects[i] = object;
      return newObjects;
    }
  }
  return newObjects;
}

Object[ARR_BND] addObjs(Object[ARR_BND] objects1, Object[ARR_BND] objects2) {
  Object[ARR_BND] newObjects = objects1;
  for (int i = 0; i < ARR_BND; i++) {
    if (newObjects[i] == null) {
      newObjects[i::(ARR_BND - i)] = objects2[0::(ARR_BND - i)];
    }
  }
  return newObjects;
}

Object[ARR_BND] removeObjFromArray(Object[ARR_BND] objects, Object object) {
  Object[ARR_BND] newObjects;
  int objectIndex = ARR_BND;
  for (int i = 0; i < ARR_BND; i++) {
    if (objects[i] == object) {
      objectIndex = i;
    }
    if (i >= objectIndex) {
      if (i == ARR_BND - 1) {
        newObjects[i] = null;
      } else {
        newObjects[i] = objects[i + 1];
      }
    } else {
      newObjects[i] = objects[i];
    }
  }
  return newObjects;
}

// NEW
Object[ARR_BND] removeObjsFromArray(Object[ARR_BND] objects, fun mapFn) {
  Object[ARR_BND] newObjects;
  int newIndex = 0;
  for (int i = 0; i < ARR_BND; i++) {
    Object object = objects[i];
    if (!mapFn(objects[i])) {
      newObjects[newIndex++] = object;
    }
  }
  return newObjects;
}

// NEW
Object removeObj(Object object) {
  object.alive = false;
  return object;
}

Object[ARR_BND] updateObjArray(Object[ARR_BND] objects, fun map_fn) {
  Object[ARR_BND] newObjects;
  for (int i = 0; i < ARR_BND; i++) {
    if (objects[i] != null) {
      newObjects[i] = map_fn(objects[i]);
    } else {
      newObjects[i] = objects[i];
    }
  }
  return newObjects;
}


// adjacent positions
Position[ARR_BND] adjPositions(Position position) {
  int x = position.x;
  int y = position.y;
  Position[4] positions = { new Position(x=x+1, y=y),
                            new Position(x=x-1, y=y),
                            new Position(x=x, y=y-1),
                            new Position(x=x, y=y+1) };

  Position[4] retVal;
  int retIndex = 0;

  for (int i = 0; i < 4; i++) {
    if (isWithinBoundsPosition(positions[i])) {
      retVal[retIndex++] = positions[i];
    }
  }
  return retVal;
}

// NEW (ALL BELOW)

// is free functions

bit isFreePosition(Scene scene, Position position) {
  Object[ARR_BND] objects = flattenSceneObjects(scene.objects);
  Object object;
  for (int i = 0; i < ARR_BND; i++) {
    object = objects[i];
    if (object != null) {
      if (object.origin.x == position.x && object.origin.y == position.y) {
        return false;
      }
    }
  }
  return true;
}

bit isFreeClick(Scene scene, Click click) {
  return isFreePosition(scene, click.position);
}

// unitVector

Position unitVector(Position position1, Position position2) {
  int deltaX = position2.x - position1.x;
  int deltaY = position2.y - position1.y;
  if (abs(sign(deltaX)) == 1 && abs(sign(deltaY)) == 1) {
    return new Position(x=1, y=0);
  } else {
    return new Position(x=sign(deltaX), y=sign(deltaY));
  }
}

int sign(int num) {
  if (num > 0) {
    return 1;
  } else {
    if (num < 0) {
      return -1;
    } else {
      return 0;
    }
  }
}

int abs(int num) {
  if (num > 0) {
    return num;
  } else {
    return -num;
  }
}


// displacement
Position displacement(Position position1, Position position2) {
  return new Position(x=position2.x - position1.x, y=position2.y - position1.y);
}

// adjacent
bit isAdjacentPosition(Position position1, Position position2) {
  int deltaX = position2.x - position1.x;
  int deltaY = position2.y - position1.y;
  if (abs(deltaX) == 1 && deltaY == 0) {
    return true;
  } else {
    if (abs(deltaY) == 1 && deltaX == 0) {
      return true;
    } else {
      return false;
    }
  }
}

Object objectClicked(Click click, Object[ARR_BND] objects) {
for (int i = 0; i < ARR_BND; i++) {
  Object obj = objects[i];
  if (obj != null) {
    if (obj.origin.x == click.position.x && obj.origin.y == click.position.y) {
      return obj;
    }
  }
}
return null;
}

bit isAdjacentObject(Object object1, Object object2) {
if (intersectsObjObj(object1, object2)) {
  return false;
}
Cell[ARR_BND] cells1 = renderObj(object1);
Cell[ARR_BND] cells2 = renderObj(object2);
for (int i = 0; i < ARR_BND; i++) {
  Cell cell1 = cells1[i];
  if (cell1 != null) {
    Position[ARR_BND] neighbors = adjPositions(cells1[i].position);
    for (int j = 0; j < ARR_BND; j++) {
      Cell cell2 = cells2[j];
      if (cell2 != null) {
        for (int k = 0; k < ARR_BND; k++) {
          Position neighborPos = neighbors[k];
          if (neighborPos != null) {
            if (cell2.position.x == neighborPos.x && cell2.position.y == neighborPos.y) {
              return true;
            }
          }
        }
      }
    }
  }
}
return false;
}

int distanceObjs(Object object1, Object object2) {
return distancePositions(object1.origin, object2.origin);
}

int distancePositions(Position position1, Position position2) {
return abs(position2.x - position1.x) + abs(position2.y - position1.y);
}

Object closest(Scene scene, Object object, char[STR_BND] type) {
Object[ARR_BND] objects = flattenSceneObjects(scene.objects);
int minDist = 2 * GRID_SIZE + 1;
Object closestObj;
for (int i = 0; i < ARR_BND; i++) {
  Object object2 = objects[i];
  if (object2.type == type) {
    int dist = distanceObjs(object2, object);
    if (dist < minDist) {
      minDist = dist;
      closestObj = object2;
    }
  }
}
return closestObj;
}

Object[ARR_BND] initObjectPositions(fun constructor, fun filterFun) {
int maxGridIndex = GRID_SIZE * GRID_SIZE - 1;
Object[ARR_BND] objects;
int objectIndex = 0;
for (int i = 0; i < maxGridIndex; i++) {
  Position pos = new Position(x=i%GRID_SIZE, y=i/GRID_SIZE);
  if (filterFun(pos)) {
    objects[objectIndex++] = constructor(pos);
  }
  if (objectIndex >= ARR_BND) {
    return objects;
  }
}
return objects;
}
/* functions that use generated functions*/
Object move(Object object, Position position) {
return updateObjOrigin(object, new Position(x=object.origin.x+position.x,y=object.origin.y+position.y));
}

Object moveNoCollision(Object object, Position position, Scene scene) {
Object movedObject = move(object, position);
if (!intersectsScene(scene, movedObject)) {
  return movedObject;
} else {
  return object;
}
}

Position getObjOrigin(Object object) {
  return object.origin;
}

bit getObjAlive(Object object) {
  return object.alive;
}

Cell[ARR_BND] getObjRender(Object object) {
  return object.render;
}

int getPositionX(Position position) {
  return position.x;
}

int getPositionY(Position position) {
  return position.y;
}

Position getCellPosition(Cell cell) {
  return cell.position;
}

/*
char[STR_BND] getCellColor(Cell cell) {
  return cell.color;
}
*/

bit and(bit b1, bit b2) {
  return b1 == b2;
}

bit or(bit b1, bit b2) {
  return b1 || b2;
}

bit not(bit b) {
  return !b;
}

bit equalsInt(int i1, int i2) {
  return i1 == i2;
}

bit equalsBit(bit b1, bit b2) {
  return b1 == b2;
}

bit equalsPosition(Position pos1, Position pos2) {
  return (pos1.x == pos2.x) && (pos1.y == pos2.y);
}

bit equalsCell(Cell cell1, Cell cell2) {
  return equalsPosition(cell1.position, cell2.position) && (cell1.color == cell2.color);
}

"""

#=
/*

Object moveWrap() {}

Object rotate() {}

Object rotateNoCollision() {}

Object nextLiquid() {}

Object nextSolid() {}
*/

=#

#=
  (: initObjectPositions (-> fun fun (List Object)))
  (: updateObjArray (-> (List Object) fun (List Object)))
  (: removeObjsFromArray (-> (List Object) fun (List Object)))
  (: closest (-> Scene Oject String Object))

=#

end
