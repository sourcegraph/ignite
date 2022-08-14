package dmlegacy

import (
	"context"
	"fmt"
	"io/ioutil"
	"os/exec"
	"path"
	"strconv"
)

// loopDevice is a helper struct for handling loopback devices for devicemapper
type loopDevice struct {
	path string
}

func newLoopDev(ctx context.Context, file string, readOnly bool) (*loopDevice, error) {
	args := []string{
		"--find",
		"--show",
		file,
	}
	if readOnly {
		args = append(args, "--read-only")
	}
	cmd := exec.CommandContext(ctx, "losetup", args...)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to setup loop device for %q: %v", file, err)
	}

	// Strip of newline at the end.
	return &loopDevice{path: string(out)[:len(out)-1]}, nil
}

func (ld *loopDevice) Path() string {
	return ld.path
}

func (ld *loopDevice) Detach() error {
	cmd := exec.CommandContext(context.Background(), "losetup", "--detach", ld.path)
	_, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to detach loop device %q: %v", ld.path, err)
	}
	return nil
}

func (ld *loopDevice) Size512K() (uint64, error) {
	data, err := ioutil.ReadFile(path.Join("/sys/class/block", path.Base(ld.path), "size"))
	if err != nil {
		return 0, err
	}

	// Remove the trailing newline and parse to uint64
	return strconv.ParseUint(string(data[:len(data)-1]), 10, 64)
}

// dmsetup uses stdin to read multiline tables, this is a helper function for that
func runDMSetup(name string, table []byte) error {
	cmd := exec.Command(
		"dmsetup", "create",
		"--verifyudev", // if udevd is not running, dmsetup will manage the device node in /dev/mapper
		name,
	)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}

	if _, err := stdin.Write(table); err != nil {
		return err
	}

	if err := stdin.Close(); err != nil {
		return err
	}

	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("command %q exited with %q: %w", cmd.Args, out, err)
	}

	return nil
}
