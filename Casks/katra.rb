# Written by hand for v0.1.0, and it should not have been.
#
# katra's .goreleaser.yml has a `homebrew_casks` block that generates this file
# and pushes it here. It did not run: the cross-repo push needs a PAT in
# HOMEBREW_TAP_GITHUB_TOKEN, that secret is not set, and `skip_upload` turns the
# tap update into a no-op rather than a failure. So the v0.1.0 release went
# green, shipped eleven assets, and silently did not update the tap.
#
# This file matches what goreleaser would have generated, so that setting the
# secret and re-running produces the same content rather than a conflict.
#
# ONE DELIBERATE DIVERGENCE: `desc` is shortened. goreleaser's `description`
# is 121 characters and starts with an article, which fails `brew style` on
# three counts (Cask/Desc length, Cask/Desc article, Layout/LineLength). The
# same shortened string has been routed to katra's .goreleaser.yml so the next
# generated file matches this one instead of conflicting with it.
#
# THE FIX IS THE SECRET, NOT THIS FILE. Once HOMEBREW_TAP_GITHUB_TOKEN exists,
# delete this comment and let the generator own the file.

cask "katra" do
  version "0.1.0"

  on_arm do
    sha256 "e7b7a902a028663db89e4f7b2ff14b292482aa3c9b97ac495a26e78c5e2baee9"

    url "https://github.com/craigjmidwinter/katra/releases/download/v#{version}/katra_#{version}_darwin_arm64.tar.gz",
        verified: "github.com/craigjmidwinter/katra/"
  end
  on_intel do
    sha256 "729d980619c971954cb940de70a6f51fb7b25006466fcded77312d3c537a909d"

    url "https://github.com/craigjmidwinter/katra/releases/download/v#{version}/katra_#{version}_darwin_amd64.tar.gz",
        verified: "github.com/craigjmidwinter/katra/"
  end

  name "katra"
  desc "Committed dev log you write as you build, stamped with its commit"
  homepage "https://github.com/craigjmidwinter/katra/"

  binary "katra"
  binary "katra-mcp"

  # The release binaries are not Apple-notarized, so Gatekeeper quarantines them
  # on download. Strip the attribute the way Homebrew itself recommends for
  # unsigned binaries.
  postflight do
    if system_command("/usr/bin/xattr", args: ["-h"]).exit_status.zero?
      system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{staged_path}/katra"]
      system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{staged_path}/katra-mcp"]
    end
  end
end
