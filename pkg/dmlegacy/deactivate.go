package dmlegacy

import (
	"path"
	"strings"

	log "github.com/sirupsen/logrus"
	api "github.com/weaveworks/ignite/pkg/apis/ignite"
	"github.com/weaveworks/ignite/pkg/util"
)

// dmsetupNotFound is the error message when dmsetup can't find a device.
const dmsetupNotFound = "No such device or address"
const dmsetupResourceBusy = "Device or resource busy"

// DeactivateSnapshot deactivates the snapshot by removing it with dmsetup. The
// loop device will automatically be cleaned, since it has been detached before.
func DeactivateSnapshot(vm *api.VM) error {
	dmArgs := []string{
		"remove",
		"--retry",      // udev might hold a lock briefly, so we have to retry to make sure this can work.
		"--verifyudev", // if udevd is not running, dmsetup will manage the device node in /dev/mapper
		vm.PrefixedID(),
	}

	// If the base device is visible in "dmsetup", we should remove it
	// The device itself is not forwarded to docker, so we can't query its path
	// TODO: Improve this detection
	baseDev := vm.NewPrefixer().Prefix(vm.GetUID(), "base")
	if _, err := util.ExecuteCommand("dmsetup", "info", baseDev); err == nil {
		dmArgs = append(dmArgs, baseDev)
	}

	if _, err := util.ExecuteCommand("dmsetup", dmArgs...); err != nil {
		// If the device is not found, it's been deleted already, return nil.
		if strings.Contains(err.Error(), dmsetupNotFound) {
			return nil
		}
		if strings.Contains(err.Error(), dmsetupResourceBusy) {
			log.Warnf("Resource busy error encountered")
			{
				out, err2 := util.ExecuteCommand("dmsetup", "info", "-c", vm.PrefixedID(), baseDev)
				if err2 != nil {
					log.Warnf("Failed to get more info on device or resource busy error: dmsetup info: %s", err2)
				}
				log.Warnf("dmsetup info returns: %s", out)
			}

			{
				out, err2 := util.ExecuteCommand("lsof", path.Join("/dev/mapper", vm.PrefixedID()))
				if err2 != nil {
					log.Warnf("Failed to get more info on device or resource busy error: lsof: %s", err2)
				}
				log.Warnf("potential users of the file: %s", out)

			}
		}
		return err
	}

	return nil
}
