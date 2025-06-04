# Smooth life project notes

## Can a texture in the bind group be changed without recreating the bind group?

> https://github.com/gfx-rs/wgpu/discussions/1495
> Currently, the only way to update a bind group resource is to create an entirely new bind group.

> https://github.com/gpuweb/gpuweb/issues/915
> https://github.com/gpuweb/gpuweb/issues/5186


## Logic

> https://www.youtube.com/watch?v=q7krkdvXoNw
> inner circle radius 4 (m) and outer circle radius 12 (n)
> add life: (m < 0.5 and n > 0.25 and n < 0.33) or (m > 0.5 and n > 0.35 and n < 0.51)
> sub life: elsewhere

> Another implementation is here:
> https://github.com/rreusser/demos/blob/master/smooth-life/index.js or
> https://github.com/rreusser/regl-smooth-life/blob/master/www/index.js

## For inspiration

> https://www.youtube.com/watch?v=6kiBYjvyojQ
