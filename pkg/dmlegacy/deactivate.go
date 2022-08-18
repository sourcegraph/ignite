package dmlegacy

import (
	"context"
	"errors"
	"fmt"
	"strings"

	api "github.com/weaveworks/ignite/pkg/apis/ignite"
	"github.com/weaveworks/ignite/pkg/util"
)

// dmsetupNotFound is the error message when dmsetup can't find a device.
const dmsetupNotFound = "No such device or address"

// DeactivateSnapshot deactivates the snapshot by removing it with dmsetup. The
// loop device will automatically be cleaned, since it has been detached before.
func DeactivateSnapshot(vm *api.VM) error {
	var errs []error
	if err := removeDeviceMapping(context.Background(), vm.PrefixedID()); err != nil {
		errs = append(errs, err)
	}

	// If the base device is visible in "dmsetup", we should remove it
	// The device itself is not forwarded to docker, so we can't query its path
	// TODO: Improve this detection
	baseDev := vm.NewPrefixer().Prefix(vm.GetUID(), "base")
	if _, err := util.ExecuteCommand("dmsetup", "info", baseDev); err == nil {
		if err := removeDeviceMapping(context.Background(), baseDev); err != nil {
			errs = append(errs, err)
		}
	}

	if len(errs) > 0 {
		errStr := "failed to deactivate snapshot:"
		for _, err := range errs {
			errStr += fmt.Sprintf("\n - %s", err.Error())
		}
		return errors.New(errStr)
	}
	return nil
}

func removeDeviceMapping(ctx context.Context, name string) error {
	dmArgs := []string{
		"remove",
		"--retry",      // udev might hold a lock briefly, so we have to retry to make sure this can work.
		"--verifyudev", // if udevd is not running, dmsetup will manage the device node in /dev/mapper
		name,
	}
	if _, err := util.ExecuteCommand("dmsetup", dmArgs...); err != nil {
		// If the device is not found, it's been deleted already, return nil.
		if strings.Contains(err.Error(), dmsetupNotFound) {
			return nil
		}
		return err
	}

	return nil
}
