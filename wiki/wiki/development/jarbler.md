---
title: Jarbler
type: entity
subtype: external
status: draft
tags: [panorama, architecture, release, tool]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2025-05_Jarbler.pdf, panorama-repository.md]
---

# Jarbler

A tool by Panorama's author that packs a Ruby application into a self-starting
Java JAR file, based on JRuby. It is what turns the [Panorama](../usage/panorama.md) source tree into
`Panorama.jar`.

## Summary

([Talks on Jarbler and MOVEX CDC](../sources/talks-jarbler-and-movex-cdc.md), talk of 2025-05;
<https://github.com/rammpeter/jarbler>.) The purpose: run a Ruby application on
a target machine that has Java but no Ruby environment. It is preconfigured for
Rails applications, so that for the simple case a configuration is hardly
needed.

## How it is used

```bash
jarble config     # generates config/jarble.rb
jarble            # builds the jar
java -jar app.jar
```

The settings that matter, in `config/jarble.rb`:

| Setting | Meaning |
|---|---|
| `config.executable` | the file to run inside the JAR |
| `config.executable_params` | its arguments |
| `config.includes` / `config.excludes` | what goes into the JAR |
| `config.jar_name` | name of the result |
| `config.excluded_gems` | gems to leave out |
| `config.java_opts` | options for compiling the small Java launcher |
| `config.compile_ruby_files` | whether Ruby sources are precompiled |

## How Panorama uses it

From `config/jarble.rb` in the repository ([Panorama source repository](../sources/panorama-source-code.md)):

- executable `bin/rails`, parameters `server -e production -p 8080`
- `--release 21` for the launcher, since JRuby 10 requires Java 21
- Ruby files are not precompiled
- `vendor/` is excluded — its assets are already precompiled into `public/`
- the gems listed in `excluded_gems.txt` are left out

The whole build is described in [Building, testing and releasing Panorama](panorama-build-test-and-release.md).

## Known rough edges

The talk does not hide them (slide 6):

- A fresh **Rails 8.0.2** application did not start from the JAR: Bundler
  ignored the `puma` gem "because it is missing extensions".
- With **Rails 6.1 and JRuby 9.4** it worked after adjustments:
  `concurrent-ruby` pinned to 1.3.4 (Rails failed with 1.3.5), Webpacker
  removed, `sass-rails` removed because `sassc` has native extensions.
- `rails server` "did not react in production mode — known issue, but forgot
  solution"; the demo ran in development mode.

> Conclusion: the recurring theme is **native extensions and gem version
> clashes** — gems that assume C Ruby, or two versions of a default gem meeting
> inside the JAR. Panorama's `excluded_gems.txt` (with comments such as "use the
> last version without prism dependency, because prism needs native extensions")
> is the accumulated answer to exactly this class of problem. That list is
> therefore not incidental configuration but the part of the build most likely
> to need attention on a Rails or JRuby upgrade.

**Apparent contradiction.** The talk of May 2025 shows Rails 8.0 failing in a
JAR; Panorama runs Rails 8.1 from a JAR built by Jarbler. Both hold: the demo was
an untouched new Rails application, Panorama is a tuned one. What exactly made
the difference is not documented in either source.

## History

Earlier, Panorama was distributed as a self-starting **WAR** file — the 2022
talk still says so, the 2024 talk says JAR ([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)).
Traces of the WAR era remain in the code, for instance a path-length check that
mentions a `Panorama.war` inside a Jetty work directory, and a comment about
`-Dwarbler.port` in the Docker start script.

> Conclusion: the name and the role suggest Jarbler was written as a replacement
> for Warbler, the established JRuby packager that produces WAR files. Neither
> source states the reason for the switch.

## Relationships

- Used by [Building, testing and releasing Panorama](panorama-build-test-and-release.md); configured in the repository
  described in [Panorama source repository](../sources/panorama-source-code.md).
- Makes the "one self-contained file" of [Panorama architecture](panorama-architecture.md) possible.
- How the JAR is run: [Panorama operations](../usage/panorama-operations.md).
- Another tool by the same author: [MOVEX CDC](../usage/movex-cdc.md) (which ships as a Docker image
  only).

## Open questions

- Why was Warbler replaced, and when exactly?
- What resolved the Rails 8 start problem for Panorama?
- What was the forgotten solution for `rails server` in production mode — is it
  the `executable_params` Panorama passes?

## Sources

- [Talks on Jarbler and MOVEX CDC](../sources/talks-jarbler-and-movex-cdc.md)
- [Panorama source repository](../sources/panorama-source-code.md)
