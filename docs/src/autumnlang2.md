# Autumn Language

The objective of the Autumn Language is to enable succinct representation of probabilistic causal probabilistic models.

# Principles

All values in Autumn are time-varying; time invariant values are considered the special case.

Autumn focuses on three kinds of time-varying value $v_t$: the value $v$ at time $t$:

1. Time invariant: $v_t$ is a constant $c$, i.e., invariant to time.

```math
v_t = c
```

2. Stateless and Time varying: $v_t$ is a function of only time.

```math
v_t = f(t)
```

3. Stateful/recurrent sequence: $v_t$ is defined in terms of previous values.

```math
v_1 = c\\
v_t = f(v_{t - 1})
```

The recurrent sequence form generalizes the other forms, and hence in Autumn we will assume all values are of this form.

## Time-varying values

In Autumn, values are specified by defining the two expressions in the recurrence relation: the initial value and the value as a function of previous values.  These are constructed using primitive language constructs `init` and `next`.

Let's recreate the three cases above in Autumn.

1. Time invariant values are simply constants.

```elm
init v = 3
next v = 3
```

This can also be expressed more succinctly as simply:

```elm
v = 3
```

2. Stateless\time varying value are simply functions of `time`.

```elm
init v = iseven (init time)
next v = iseven time
```

This can be expressed more succintly as simply applying a function to an existing time varying value:

```elm
v = iseven time
```

3. Stateful/recurrent time varying make usue of previous values:

The simplest example is perhaps `time` itself, which need not be defined as a primitive, but can be expressed in the language using the primitive `prev` which returns the value at the previous time step:

```elm
init time = 1
next time = (prev time) + 1
```

A more complex is a value that evolves according to the fibonnaci sequence in Autumn: 

```elm
init fib = 0
next fib = if time == 1
           then 1
           else (prev fib) + (prev prev fib) 
```

## Anonymous Values
In functional programming, a name a value is bound to is independent from the value itself.
In particular, not every value needs to be bound to a name.
The above examples defined recurrence relation using names (for instance, `next fib` refers to `(prev fib)`).
We must now define how to define recurrence relations when we do not explicitly have names.
This problem is very similar to the problem of defining recursion for anonymous functions: how can a function recurse if it has no name to call itself with?
One solution to that problem is to introduce primitives to allow a function to reflect on itself.
We will use a similar approach here:

Consider defining a value equivalent to `time` above, but without the use of a name.
In English, we might say something like:

(1) At time 0, this value is 1

(2) At every other time, the value is __this__ value's previous value + 1

Autumn takes a similar approach using the primitive `this` to describe time varying values

```elm
time = init 1 next prev (this) + 1
```

## Patterns

We can express several patterns using the machinery described above.

### Lifting

A common pattern is that some value `q` should vary immediately as a function `f` of some other time varying value `v`.
We can express this as:

```elm
q = init f (first v) next f v
```

We can also, much more succintly, express this as simply applying `f` to `v`

```elm
q = f v
```

### Events
Another useful pattern describes values that change on the occurance of an event.

For example, the following value `x` is `4` until the event `keyPress` has occured, and then it is `10` 

```elm
x = 4 until midnight then 10
```

The occurence (or non occurence) of an event does not require any special machinery.
We can do something very similar to `Maybe` types -- define the type `Event a`

```elm
type Event a = Occured a | Nothing

-- Did event occur?
occured : Event a -> Bool
occured event = 
  case (Event a) of
    Just a -> true
    a -> false
```

```
``` 

The `until` command can then be expressed as a function:

```
until initValue event newValue = 
  {{initValue, if (occured event) then this else newValue}}
```

### External Signals
Some time-varying values rely on external input.

All external signals are defined using the `external` primitive, which defines the type of the external symbol.

```elm
external x : Int
```


## Probability
Autumn ptograms may be probabilistic.   A probabilistic autumn program contains at least one value that is uncertain.

Autumn contains a primitive uniform value: `unif`:

```elm
x = unif
```

`unif` is time varying.  If a constant value is needed then as is always the case we can use `init`.

FIXME: Does this make sense, does this clash with pointwise?

```elm
x = init unif
```

Autumn is a functional, and hence in the following program, both `x` and `y` are the same value

```elm
x = unif
y = unif
```

If two independent uniformly distributed random values are needed, then:

```elm
x = unif 1
y = unif 2
```

A more complex example is a geometric distribution:

```elm
flip : Bool
flip = unif > 0.5

geometric : Int -> Int
geometric n =
  if flip
  then geometric n + 1
  else n

x = geometric 1
```

What's tricky about the above exmaple, is that for every recursive call to geometric, we want an independent flip.
## Full Programs

The following example shows a particle simulator.
At each time step, particles will move randomly into a free space around them, if one exists.


-- FIXME:

```elm
type alias Position = (Int, Int)
type Particle = Particle position:Position

particles : [Particle]
init particles = []
next particles = if buttonPress
                 then particles :: Particle (1, 1)
                 else particles

-- Lifted (automatically)
nparticles = length particles

isfree : Position -> Bool
isfree position = not (all (map \particle -> particle in position particles))

-- At every time step, look for a free space around me and try to move into it
nextPosition : Particle -> Position
nextPosition particle =
  let
    freePositions = filter isfree (adjacentPositions particle.position)
  in
    case freePositions
      [] -> particle
      _ -> uniformChoice freePositions

particleGen position = Paricle position 

-- Here's a particular particule
aParticle : Particle
init aParticle = Particle (1, 1)
next aParticle = nextPosition (prev aParticle)

-- Maps an initial position to a particle that chooses its next position
-- using nextPosition, which depends on `particles`
particleGen initPosition = 
  {{Particle initPosition, nextPosition this}}
```

## Implementation

An efficient implementation of the Autmn language is challenging, because any value could concievably access the history of any previous value.
For the domains of interest it's feasible to track every value.  I plan to simply do this.

