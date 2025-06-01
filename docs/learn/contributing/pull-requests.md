# Submitting Pull Requests

When submitting a Pull Request, there's a few reasons to do so:


## Documentation

If there's something to change with the documentation, you should follow a similar format to this example:

An example of an appropriate typo-fixing PR would be:

>**Brief Description of your Changes**
>
>I fixed a couple of typos found in the /contributing/issues.md file.
>
>**Impact of your Changes**
>
>- Documentation is more clear and readable for the users.
>
>**Tests Performed**
>
>Ran `vitepress dev docs` and verified it was built successfully.
>
>**Additional Comments**
>
>[At Discretion]

## Change in Behavior

An example of an appropriate PR that adds a new feature would be:

>
>**Brief Description of your Changes**
>
>I added `jecs.best_function`, which gives everyone who uses the module an immediate boost in concurrent player counts. (this is a joke)
>
>**Impact of your Changes**
>
>- jecs functionality is extended to better fit the needs of the community [explain why].
>
>**Tests Performed**
>
>Added a few test cases to ensure the function runs as expected [link to changes].
>
>**Additional Comments**
>
>[At Discretion]

## Addons

If you made something you think should be included into the [resources page](../../resources), let us know!

We have tons of examples of libraries and other tools which can be used in conjunction with jecs on this page.

One example of a PR that would be accepted is:

>**Brief Description of your Changes**
>
>I added `jecs observers` to the addons page.
>
>**Impact of your Changes**
>
>- jecs observers are a different and important way of handling queries which benefit the users of jecs by [explain why your tool benefits users here]
>
>- [talk about why you went with this design instead of maybe an alternative]
>
>**Tests Performed**
>
> I used this tool in conjunction with jecs and ensured it works as expected.
>
> [If you wrote unit tests for your tool, mention it here.]
>
>**Additional Comments**
>
>[At Discretion]

Keep in mind the list on the addons page is *not* exhaustive. If you came up with a tool that doesn't fit into any of the categories listed, we still want to hear from you!
