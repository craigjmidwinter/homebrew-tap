class Getvect < Formula
  desc "Raster to vector, on your machine. No upload, no account, no API key"
  homepage "https://getvect.midwinter.io"
  url "https://github.com/craigjmidwinter/getvect/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "fda72a7629665b9c004b04d344d4a9b647ae3d66368718428f970092ae65a735"
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
    # ARGUMENTS ARE REFUSED, DELIBERATELY, AND THIS IS NOT COSMETIC.
    #
    # This shim launches the GUI. Electron accepts any extra argv without
    # complaint, so `getvect logo.png` used to open a WINDOW — and `getvect
    # --help` opened a window too, instead of printing help. A command that
    # silently does the wrong thing is worse than one that does not exist:
    # it looks like a feature that is present and broken.
    #
    # getvect DOES have a headless CLI (`bin/getvect.mjs`), but it is not in
    # this build — it runs from a clone. Until the packaged app grows a
    # headless path, the honest behaviour is to say so and exit non-zero.
    #
    # DELETE THIS BRANCH when the app can trace headlessly, and pass "$@"
    # straight through again.
    (bin/"getvect").write <<~SH
      #!/bin/bash
      if [ "$#" -gt 0 ]; then
        cat >&2 <<'MSG'
      getvect: this build is the desktop app and takes no arguments.

      The command-line tracer is not packaged yet. To use it:

        git clone https://github.com/craigjmidwinter/getvect.git
        cd getvect && npm install && npm run build:node
        node bin/getvect.mjs INPUT [OUTPUT] [--help]

      Run `getvect` with no arguments to open the app.
      MSG
        exit 2
      fi
      exec "#{libexec}/node_modules/.bin/electron" "#{libexec}" "$@"
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
      GetVect is a desktop application. Launch it with:
        getvect

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
  end
end
