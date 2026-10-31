# Facts give each host's architecture, which picks the SDK tarball, and its
# distribution and release, which pick the library package names.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = contains(keys(local.rids), self.arch)
      error_message = "Host ${each.key} is ${self.arch}. This circuit installs the linux-x64 and linux-arm64 builds."
    }
  }
}

locals {
  rids    = { x86_64 = "x64", aarch64 = "arm64" }
  rid     = { for name in keys(var.hosts) : name => lookup(local.rids, data.conn3x_host.facts[name].arch, data.conn3x_host.facts[name].arch) }
  home    = "/opt/dotnet/${var.sdk_version}"
  tarball = { for name, r in local.rid : name => "dotnet-sdk-${var.sdk_version}-linux-${r}.tar.gz" }

  # Debian and Ubuntu put ICU's soname in the package name. libicu-dev pulls in
  # the right one on a release this doesn't know, with headers you don't need.
  libicu = { "24.04" = "libicu74", "13" = "libicu76" }
}

circuit "dotnet" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "tool" {
    for_each = ["curl", "tar", "gzip", "ca-certificates"]
    package {
      name = item.value
    }
  }

  # openssl brings libssl under its own name on each family. Fedora 45 moved on
  # to OpenSSL 4, which .NET 10 can't load, and keeps libssl.so.3 in a package
  # of its own.
  step "libssl" {
    package {
      name = data.conn3x_host.facts[each.key].os_id == "fedora" ? "openssl3-libs" : "openssl"
    }
  }

  # .NET's own dependency list, in each family's names.
  step "libstdcxx" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "libstdc++6" : "libstdc++"
    }
  }

  step "kerberos" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "libgssapi-krb5-2" : "krb5-libs"
    }
  }

  step "icu" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? lookup(local.libicu, data.conn3x_host.facts[each.key].os_version, "libicu-dev") : "libicu"
    }
  }

  step "dir" {
    for_each = ["/opt/dotnet", local.home, "/etc/dotnet"]
    directory {
      path = item.value
    }
  }

  # The download step keeps the tarball only if it matches the checksum.
  step "download" {
    download {
      url    = "https://builds.dotnet.microsoft.com/dotnet/Sdk/${var.sdk_version}/${local.tarball[each.key]}"
      sha256 = var.checksums[local.rid[each.key]]
      dest   = "/opt/dotnet/${local.tarball[each.key]}"
    }
  }

  step "unpack" {
    archive {
      src     = "/opt/dotnet/${local.tarball[each.key]}"
      dest    = local.home
      creates = "${local.home}/dotnet"
    }
  }

  # A small script instead of a link, because the telemetry setting is an
  # environment variable. /etc/profile.d would miss cron, systemd and commands
  # run over SSH without a login shell.
  step "command" {
    file {
      path    = "/usr/local/bin/dotnet"
      content = "#!/bin/sh\n# Written by Conn3x. Changes here are overwritten on the next apply.\n${var.telemetry ? "" : "export DOTNET_CLI_TELEMETRY_OPTOUT=1\n"}exec ${local.home}/dotnet \"$@\"\n"
      mode    = "0755"
    }
  }

  # Where a built application's own launcher looks for the runtime.
  step "install_location" {
    file {
      path    = "/etc/dotnet/install_location"
      content = "${local.home}\n"
      mode    = "0644"
    }
  }
}
