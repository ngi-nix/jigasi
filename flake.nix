{
  description = "Jitsi Gateway to SIP : a server-side application that links allows regular SIP clients to join Jitsi Meet conferences hosted by Jitsi Videobridge.";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }:
    let

      # Generate a user-friendly version numer.
      #version = "${builtins.substring 0 8 self.lastModifiedDate}-${self.shortRev or "dirty"}";
      version = "1.1-195-g65ef768-1";

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

      src = builtins.fetchurl {
        url = "https://download.jitsi.org/stable/jigasi_${version}_amd64.deb";
        sha256 = "0fq4gb4pib5bm5bdh9qr1xszzwn8ryar0n3a32s333zq5hpv9xb4";
      };

    in {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        jigasi = with final; final.callPackage ({ inShell ? false }: stdenv.mkDerivation rec {
          name = "jigasi-${version}";

          inherit version src;

          dontBuild = true;

          unpackCmd = "${dpkg}/bin/dpkg-deb -x $src debcontents";

          nativeBuildInputs = [ makeWrapper ];

          installPhase = ''
            runHook preInstall
            substituteInPlace usr/share/jigasi/jigasi.sh \
              --replace "exec java" "exec ${jre_headless}/bin/java"
            mkdir -p $out/{bin,share/jigasi,etc/jitsi/jigasi}
            mv etc/jitsi/jigasi/* $out/etc/jitsi/jigasi/
            mv usr/share/jigasi/* $out/share/jigasi/
            ln -s $out/share/jigasi/jigasi.sh $out/bin/jigasi
            # work around https://github.com/jitsi/jitsi-videobridge/issues/1547
            wrapProgram $out/bin/jigasi \
              --set VIDEOBRIDGE_GC_TYPE G1GC
            runHook postInstall
          '';

          meta = with lib; {
            description = "Jitsi Gateway to SIP : a server-side application that links allows regular SIP clients to join Jitsi Meet conferences hosted by Jitsi Videobridge.";
            longDescription = ''
            '';
            homepage = "https://github.com/jitsi/jigasi";
            license = licenses.asl20;
            maintainers = teams.jitsi.members;
            platforms = platforms.linux;
          };
        }) {};

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) jigasi;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.jigasi);

      # Provide a 'nix develop' environment for interactive hacking.
      devShell = forAllSystems (system: self.packages.${system}.jigasi.override { inShell = true; });
 
    };
}
