-- These notes are my thoughts jotted down from having experienced these
-- problems myself and gathered insights from many admired individuals such as
-- Sander Mertens, Ryan Fleury, Jonathon Blow, Benjamin Saunders and many more...

--[[

In 1993, the original source code for DOOM was about 50,000 lines of code. And
when your code gets into that neighbourhood, it should provide a large amount of
interesting and novel functionality. If it doesn't, perhaps it is time to ask questions.

Please, try to write code that is small, and that does a lot for its size.

Please, after you finish writing something, ask yourself whether you are
satisfied with how robust it is, and with how much it gets done for how much
code there is.

- Transfer of tacit knowledge is incredibly important. If tacit knowledge
about the code base is lost, ability to work on it at the same level of quality
is lost. Over time code quality will decline as code size grows.

- Tacit knowledge is very hard to recover by looking at a maze of code,
and it takes a long time to do so.

- You will often hear that "every semantic distinction deserves its own
component or tag". Sometimes this is correct. A well chosen component boundary
can make queries clear and systems obvious. But sometimes this distinction would
be better served as a field, a bitset, or a local data structure. The
representation should match the problem.

Sub-Essay Here: Code Should Not Try To Meet Every Need Anyone May Ever Have.

Over-generalization leads to bloat and poor functionality. A common failure mode
is writing code "for everyone" while building configuration for every scenario,
abstractions for every future feature, and extension points for every imagined
consumer. It sounds responsible. It usually isn't.
Specialization is good in many cases. Think about the guy with the truck full of
automotive tools, who has a bunch of different wrenches. He doesn't carry one
wrench that transforms into every tool; he carries a few specialized tools that
are reliable and fast to use. One reason we have endless bloat is that we teach
that all code should expand until it meets all needs. This is wrong,
empirically, and we should stop teaching it.

- Relationships are very powerful however, with each pair being an unique
component, it can be an easy way to accidentally increase the number of archetypes which can cause
higher churn in systems.

- A hook is not a replacement for systems. They are for enforcing invariants when data changes during different lifecycles.
When gameplay logic that should run predictably each frame is instead scattered
across hooks, behaviour becomes implicit when it is triggered indirectly through
a cascade of changes that, logic split across many small
callbacks that fire in surprising order. Which also gets harder to reason about
and optimize.

]]
