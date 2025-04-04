// Copyright © 2019 Banzai Cloud
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cistore

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"logur.dev/logur"

	"github.com/banzaicloud/cloudinfo/internal/cloudinfo/cloudinfoadapter"
	"github.com/banzaicloud/cloudinfo/internal/platform/cassandra"
)

func testCassandraStore(t *testing.T) {
	cps := NewCassandraProductStore(
		cassandra.Config{
			Hosts:    []string{"localhost"},
			Port:     9042,
			Keyspace: "test",
			Table:    "testPi",
		},
		cloudinfoadapter.NewLogger(&logur.TestLogger{}),
	)

	ctx, cancelFunction := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancelFunction()
loop:
	for {
		select {
		case <-ctx.Done():
			t.Fatalf("waiting for Cassandra product store to become ready failed, err: %s", ctx.Err().Error())
		default:
			if cps.Ready() {
				break loop
			} else {
				time.Sleep(time.Second)
			}
		}
	}

	// insert an entry
	cps.StoreStatus("amazon", "status")

	// retrieve it
	status, ok := cps.GetStatus("amazon")
	assert.True(t, ok)
	assert.Equal(t, "status", status)
}
