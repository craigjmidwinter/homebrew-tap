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

    # Drop dev dependencies AFTER building; electron itself is a runtime dep and
    # stays. `npm prune` is deliberate — shipping tsc and vite into libexec would
    # roughly double the install for no runtime benefit.
    system "npm", "prune", "--omit=dev"

    libexec.install Dir["*"]

    # The launcher. `electron .` is what `npm start` runs; this is the same path
    # without requiring the user to have a checkout.
    (bin/"getvect").write <<~SH
      #!/bin/bash
      exec "#{libexec}/node_modules/.bin/electron" "#{libexec}" "$@"
    SH
    chmod 0755, bin/"getvect"
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
    assert_predicate bin/"getvect", :executable?
  end
end
