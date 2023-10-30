# Utils

This is collection of libraries that structure game code around observable streams, binders, value objects and resource cleanup.

Most libraries are adapted from [Quenty's](https://github.com/Quenty) [NevermoreEngine](https://github.com/Quenty/NevermoreEngine).
NevermoreEngine is a comprehensive monorepo with libraries for pretty much everything, from which I've extracted the "core" libraries. They were extracted on 18/08/23, so from commit 40f9a1fad543e137f1e639cafc45a98cb439b0b6.

Individual files may have a changelog in the initial comment.

## Nevermore License
NevermoreEngine is distributed under the MIT License.

```
MIT License

Copyright (c) 2014-2023 James Onnen (Quenty)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### Other licenses
The BlendDefaultProps table from Blend.lua was credited to Elttob, and the MIT license is repeated here.
```

MIT License

Copyright (c) 2021 Elttob

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Overview

### Libraries from Nevermore
It is suggested in the README as a possible installation method to copy and paste from the source code (with modifications).
> You can also copy and paste a lot of these libraries into module scripts and with small refactors, have them running anywhere. The closer the package gets to a full-sized gameplay feature (such as Ik), the less likely this is going to be ergonomic.
Modifications have been made to every Nevermore library included, like using regular requires instead of Nevermore's loader, and compatibility changes to make them work with other libaries included.

Each library is pretty well-documented internally.

- Maid: Encapsulate cleanup logic for a resource to be destroyed later
	- Our implementation of a maid task allows for numeric tables of tasks.
- BaseObject: A table with a self._maid and a :Destroy() method
- Binder: wraps tagged instances with a class/constructor using CollectionService, and provides boilerplate for observing/querying classes.
- Binder/PlayerHumanoidBinder: creates a binder that applies tags to the humanoid of a player
	- uses observables instead of "HumanoidTracker"
- Spring: spring implementation
	- Merged SpringUtils functions into Spring
- Spring/LinearValue: Datatype interface for values that can be linearly interpolated (used for springing Color3, UDim, UDim2).
- SpringObject: Reactive object wrapper for Spring
- Step Utils: boilerplate for animating with renderstepped. Used in Blend and SpringObject.
- AccelTween
	- Author: TreyReynolds/AxisAngles
- Brio: Wraps an object(s) with a maid and an alive/dead state. Represents a "lifetime", and is useful for handling resources emitted by observables. There is more explanation in the [api page](https://quenty.github.io/NevermoreEngine/api/Brio/)
- ValueObject: Like the ValueBase Instances (IntValue, BoolValue, ObjectValue) but can store any type of value. Setting `valueObject.Value = newValue` property triggers `valueObject:SetValue(newValue)`, and therefore triggers the .Changed signal (just like ValueBase instances behave).
- Blend - Declarative instance library for UI or otherwise. Observables, ValueObjects, ValueBase instances - anything reactive, can be "blended" together to compute derived state (or assigned directly to properties). It is inspired by Fusion, but all of the instance management logic is handled with observables and maids, so the cleanup is handled explicitly, rather than implicitly via weak-key-tables + garbage collection.

## Included from Wally

These are libraries that were already in use from wally, and are linked into Utils/ with project.json files, so that all requires are Util-relative.
The project.json files need to be updated manually if the package versions are updated.

- Promise (evaera/promise@4.0.0)
	- All code Nevermore libraries above that use Promise were adapted for this version of the library (e.g. Promise.is instead of Promise.isPromise)
- GoodSignal (stravant/goodsignal@0.2.1)

## Other

- Rx, Rxi: Standalone Rx implementation by stravant
	- This was a onetime release and is not maintained. Bug fixes and extensions to these files have been made, and we will maintain/update these as needed.
	- Updated maid usage to be compatible with our Maid.