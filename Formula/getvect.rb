class Getvect < Formula
  desc "Raster to vector, on your machine. No upload, no account, no API key"
  homepage "https://getvect.midwinter.io"
  url "https://github.com/craigjmidwinter/getvect/archive/refs/tags/v0.1.6.tar.gz"
  sha256 "67db93677f4e3f6dbe980955dd2d250ac1a0b03cfafbe04fe8303d98380d35f5"
  license "MIT"

  # A FORMULA, NOT A CASK, AND THAT IS THE WHOLE POINT.
  #
  # A cask downloads a .dmg through the same path a browser uses, so macOS sets
  # com.apple.quarantine on it and Gatekeeper blocks the first launch. The usual
  # fixes are to buy an Apple Developer certificate and notarize, or to have the
  # cask run `xattr -dr com.apple.quarantine` in a postflight — which is what
  # this tap's mail-muncher cask does, and which is a workaround rather than a
  # solution: it strips a security attribute after the fact.
  #
  # A formula built from source is never quarantined in the first place, because
  # nothing arrives as a downloaded application bundle. So there is no Gatekeeper
  # prompt, no certificate to buy, and no attribute to strip. Zero marginal spend.
  #
  # It also cannot go to homebrew-core: core does not accept GUI/Electron
  # applications as formulas, and a core cask would reintroduce the quarantine
  # this exists to avoid. A tap is the correct home, not a consolation prize.

  depends_on "node"
  depends_on :macos

  def install
    # `npm install`, NOT `npm ci`, and that is a workaround for an upstream bug
    # rather than a preference. As of v0.1.1 the released tarball's
    # package-lock.json is out of sync with its package.json — `npm ci` aborts
    # with five packages "missing from lock file" (@electron/windows-sign,
    # cross-dirname, fs-extra, postject, commander). Reported upstream. Switch
    # this back to `npm ci` once a release ships a lockfile that matches, because
    # ci is the reproducible one and install resolves fresh every build.
    #
    # Build deps are needed (tsc, vite), so a full install rather than --omit=dev.
    system "npm", "install"
    system "npm", "run", "build"

    # NO `npm prune --omit=dev`. It was here until 2026-08-25 with a comment
    # claiming "electron itself is a runtime dep and stays". That was FALSE:
    # electron is a devDependency (^43.3.0), so prune deleted it and the
    # launcher below pointed at a binary that did not exist. `brew install`
    # succeeded, printed a caveat telling the user to run `getvect`, and
    # `getvect` died with "No such file or directory".
    #
    # Do NOT "fix" this by moving electron into dependencies upstream:
    # electron-builder requires it in devDependencies, and as a runtime dep it
    # gets bundled into the asar and breaks `npm run dist`. The fix belongs
    # here. The install is larger; an app that starts is worth the megabytes.

    libexec.install Dir["*"]

    # RE-SIGN Electron.app AFTER the copy into libexec.
    #
    # Electron ships an ad-hoc, linker-signed bundle. Homebrew's copy breaks the
    # signature seal — `codesign --verify` then reports "code has no resources
    # but signature indicates they must be present" and macOS SIGKILLs the app
    # at launch. Found 2026-08-25 by a peer session actually RUNNING the
    # installed binary, which this formula's original test never did.
    #
    # This repairs a signature the install itself broke. It is not a Gatekeeper
    # bypass: nothing here is quarantined, because nothing was downloaded as an
    # application bundle. Verified after this step: 0 com.apple.quarantine attrs.
    # The launcher. `electron .` is what `npm start` runs; this is the same path
    # without requiring the user to have a checkout.
    # ONE COMMAND, TWO PROGRAMS: no arguments opens the app, arguments run the
    # headless tracer. Both are in this install; the shim only chooses.
    #
    # This replaces a branch that REFUSED arguments, which was correct while
    # `bin/getvect.mjs` existed only on `main` and in no tag. v0.1.6 is the
    # first release whose source tarball contains it — verified by downloading
    # that tarball and listing it, not by trusting the tag.
    #
    # NODE IS REFERENCED BY ABSOLUTE PATH, NEVER AS BARE `node`.
    #
    # `depends_on "node"` guarantees a node exists at Homebrew's prefix. It
    # guarantees nothing about the user's PATH — they may have no node at all,
    # or a different major version than this built against. A shim that says
    # `node` works perfectly for anyone who develops in node and fails for
    # exactly the users a packaged CLI exists to serve.
    #
    # That is the ELECTRON-PRUNE BUG above with a different missing file: a
    # launcher pointing at a binary that is not there, where `brew install`
    # succeeds and the command dies. Interpolating the path at install time
    # makes it unmissable, and the test below runs with a PATH that has no
    # node so the failure cannot hide in a developer's shell.
    (bin/"getvect").write <<~SH
      #!/bin/bash
      # No arguments: the GUI, exactly as before.
      if [ "$#" -eq 0 ]; then
        exec "#{libexec}/node_modules/.bin/electron" "#{libexec}"
      fi
      # Anything else: the CLI. `exec` so the tracer's exit code and its stdout
      # and stderr reach the caller untouched — this shim adds nothing to
      # either stream and must not swallow a status.
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/bin/getvect.mjs" "$@"
    SH
    chmod 0755, bin/"getvect"
  end

  # SIGNING MUST HAPPEN HERE, NOT IN `install`.
  #
  # Electron ships an ad-hoc, linker-signed bundle. Copying it breaks the
  # signature seal and macOS SIGKILLs the app at launch. Signing inside
  # `install` does not survive: Homebrew relocates the staged tree into the
  # Cellar afterwards and breaks it again — verified, the app still SIGKILLed
  # from a clean build. `post_install` runs once the files are in their final
  # location, which is the only point at which a signature sticks.
  #
  # Sign INNERMOST-OUT. `--deep` is Apple-deprecated for signing and leaves
  # nested frameworks invalid.
  #
  # This repairs a signature the install broke. It is not a Gatekeeper bypass:
  # nothing is quarantined, because nothing arrived as a downloaded bundle.
  def post_install
    app = libexec/"node_modules/electron/dist/Electron.app"
    nested = Dir[app/"Contents/Frameworks/*.framework"] +
             Dir[app/"Contents/Frameworks/*.app"] +
             Dir[app/"Contents/Frameworks/*.dylib"]
    (nested.sort + [app]).each do |target|
      system "/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", target
    end
  end

  def caveats
    <<~EOS
      GetVect is a desktop app and a command-line tracer, both from `getvect`:

        getvect                      open the app
        getvect logo.png             trace to logo.svg
        getvect shot.jpg -f dxf      pick a format
        getvect --help               every flag

      It was built from source on this machine, so macOS has not quarantined it
      and Gatekeeper will not prompt. Conversion runs locally — no upload, no
      account, no API key.
    EOS
  end

  test do
    # Prove the engine is real and headless, not merely that files landed.
    # vectorize() is the pure entry the GUI also calls.
    (testpath/"probe.js").write <<~JS
      const { vectorize } = require("#{libexec}/dist/engine/index.js");
      if (typeof vectorize !== "function") {
        console.error("vectorize is not a function");
        process.exit(1);
      }
      console.log("ok");
    JS
    assert_equal "ok", shell_output("#{Formula["node"].opt_bin}/node #{testpath}/probe.js").strip

    # The launcher must point at something that EXISTS. Asserting only that the
    # wrapper is executable passed for an install that could not start — the
    # dead-gate pattern: a check that cannot fail for the reason it was written.
    assert_predicate bin/"getvect", :executable?
    assert_predicate libexec/"node_modules/.bin/electron", :exist?
    assert_predicate libexec/"node_modules/.bin/electron", :executable?

    # And the bundle must have a signature macOS will actually accept, or it
    # SIGKILLs on launch while every other check above still passes.
    system "/usr/bin/codesign", "--verify", "--deep", "--strict",
           libexec/"node_modules/electron/dist/Electron.app"

    # THE CLI, RUN WITH A PATH THAT HAS NO NODE ON IT.
    #
    # This is the control, and without it the test only proves that the person
    # running it has node installed. `env -i` strips the environment; the shim
    # must still work, because it interpolates Homebrew's node by absolute
    # path. A shim saying bare `node` passes every other assertion here and
    # fails for exactly the users a packaged CLI exists to serve.
    # `unpack1("m0")`, not Base64.decode64 — Homebrew no longer bundles the
    # base64 gem, and the linter is right about that one. (It is wrong about the
    # escaped backticks in a generated shell heredoc; read each offence.)
    (testpath/"in.png").write(
      ("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAFklEQVQIW2P8z8Dwn4E" \
       "IwDiqEDlkAABL0wP9UOJ8fAAAAABJRU5ErkJggg==").unpack1("m0"),
    )
    system "/usr/bin/env", "-i", "PATH=/usr/bin:/bin",
           bin/"getvect", testpath/"in.png", testpath/"out.svg"
    assert_path_exists testpath/"out.svg"
    assert_match "<svg", (testpath/"out.svg").read

    # Help answers on stdout and exits 0; a bad path exits non-zero.
    assert_match(/usage|Usage|--format/,
                 shell_output("#{bin}/getvect --help"))
    shell_output("#{bin}/getvect #{testpath}/nope.png 2>&1", 1)
  end
end
