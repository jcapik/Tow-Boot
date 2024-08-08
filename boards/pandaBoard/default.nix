{ config, lib, pkgs, ... }:

let
  inherit (config.helpers)
    composeConfig
  ;
  pandaBoard = composeConfig {
    config = {
      device.identifier = "pandaBoard";
      Tow-Boot.defconfig = "omap4_panda_defconfig";
    };
  };

  configTxt = pkgs.writeText "config.txt" ''
    [pandaboard]
    kernel=Tow-Boot.noenv.panda.bin

    [all]
    arm_64bit=0
    enable_uart=1
    avoid_warnings=1
  '';
in
{
  device = {
    manufacturer = "PandaBoard";
    name = "Combined armv7l";
    identifier = lib.mkDefault "pandaBoard-armv7";
    productPageURL = "https://www.raspberrypi.com/products/";
    # This line of boards is YMMV.
    supportLevel = "experimental";
  };

  hardware = {
    # Targets multiple broadcom SoCs
    soc = "generic-armv7l";
  };

  Tow-Boot = {
    # FIXME: a small lie for now until we get the upcoming changes in.
    defconfig = lib.mkDefault "omap4_panda_defconfig";

    config = [
      (helpers: with helpers; {
        # 64 MiB; the default unconfigured state is 4 MiB.
        SYS_MALLOC_LEN = freeform ''0x4000000'';
        CMD_POWEROFF = no;
      })

      (lib.mkIf (!config.Tow-Boot.buildUBoot) (helpers: with helpers; {
        # As far as distro_bootcmd is aware, the raspberry pi can
        # have up to three mmc "devices"
        #   - https://source.denx.de/u-boot/u-boot/-/blob/v2022.07/include/configs/rpi.h#L134-137
        # To be fixed in a refresh of the raspberry pi configs.
        # This currently adds two bogus "SD" entries *sigh*.
        # It's not an issue upstream since there is no menu; the bootcmd simply tries
        # all options in order. The bogus entries simply fail.
        TOW_BOOT_MMC0_NAME = freeform ''"SD (0)"'';
        TOW_BOOT_MMC1_NAME = freeform ''"SD (1)"'';
        TOW_BOOT_MMC2_NAME = freeform ''"SD (2)"'';
      }))
    ];
    outputs.firmware = lib.mkIf (config.device.identifier == "pandaBoard-armv7l") (
      pkgs.callPackage (
        { runCommand }:

        runCommand "tow-boot-${config.device.identifier}" {
          inherit (pandaBoard.config.Tow-Boot.outputs.firmware)
            version
          ;
        } ''
          (PS4=" $ "; set -x
          mkdir -p $out/{binaries,config,diff}
          cp -v ${pandaBoard.config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin $out/binaries/Tow-Boot.noenv.panda.bin
          cp -v ${pandaBoard.config.Tow-Boot.outputs.firmware}/config/noenv.config $out/config/noenv.panda.config
          cp -v ${pandaBoard.config.Tow-Boot.outputs.firmware}/config/noenv.newdefconfig $out/config/noenv.panda.newdefconfig
          cp -v ${pandaBoard.config.Tow-Boot.outputs.firmware}/diff/noenv.build.diff $out/diff/noenv.panda.diff
          )
        ''
      ) { }
    );
    builder.installPhase = ''
      cp -v u-boot.bin $out/binaries/Tow-Boot.$variant.bin
    '';

    # The Raspberry Pi firmware expects a filesystem to be used.
    writeBinaryToFirmwarePartition = false;

    diskImage = {
      partitioningScheme = "mbr";
    };
    firmwarePartition = {
      partitionType = "0C";
      filesystem = {
        filesystem = "fat32";
        populateCommands = ''
          cp -v ${configTxt} config.txt
          cp -v ${pandaBoard.config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin Tow-Boot.noenv.panda.bin
          (
          target="$PWD"
          cd ${pkgs.raspberrypifw}/share/raspberrypi/boot
          #cp -v bcm270{8,9}-rpi*.dtb "$target/"
          cp -v bootcode.bin fixup*.dat start*.elf "$target/"
          )
        '';

        # The build, since it includes misc. files from the Raspberry Pi Foundation
        # can get quite bigger, compared to other boards.
        size = 32 * 1024 * 1024;
        fat32 = {
          partitionID = "00F800F8";
        };
        label = "TOW-BOOT-FW";
      };
    };
  };
  documentation.sections.installationInstructions = ''
    ## Installation instructions

    ${config.documentation.helpers.genericSharedStorageInstructionsTemplate { storage = "an SD card, USB drive (if the Raspberry Pi is configured correctly) or eMMC (for systems with eMMC)"; }}
  '';
}
