package types

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestMSBIndex(t *testing.T) {
	tests := []struct {
		input    uint64
		expected int
	}{
		{0, 0},
		{1, 0},
		{2, 1},
		{4, 2},
		{8, 3},
		{16, 4},
		{255, 7},
		{1024, 10},
		{18446744073709551615, 63},
	}

	for _, test := range tests {
		result := MSBIndex(test.input)
		if result != test.expected {
			t.Errorf("MSBIndex(%d) expected %d, but got %d", test.input, test.expected, result)
		}
	}

}

type testNodeInfo struct {
	GIndex       uint64
	Depth        int
	IndexAtDepth int
	TraceIndex   uint64
	AttackGIndex uint64 // 0 indicates attack is not possible from this node
	DefendGIndex uint64 // 0 indicates defend is not possible from this node
}

var treeNodesMaxDepth4 = []testNodeInfo{
	{GIndex: 1, Depth: 0, IndexAtDepth: 0, TraceIndex: 15, AttackGIndex: 2},

	{GIndex: 2, Depth: 1, IndexAtDepth: 0, TraceIndex: 7, AttackGIndex: 4, DefendGIndex: 6},
	{GIndex: 3, Depth: 1, IndexAtDepth: 1, TraceIndex: 15, AttackGIndex: 6},

	{GIndex: 4, Depth: 2, IndexAtDepth: 0, TraceIndex: 3, AttackGIndex: 8, DefendGIndex: 10},
	{GIndex: 5, Depth: 2, IndexAtDepth: 1, TraceIndex: 7, AttackGIndex: 10},
	{GIndex: 6, Depth: 2, IndexAtDepth: 2, TraceIndex: 11, AttackGIndex: 12, DefendGIndex: 14},
	{GIndex: 7, Depth: 2, IndexAtDepth: 3, TraceIndex: 15, AttackGIndex: 14},

	{GIndex: 8, Depth: 3, IndexAtDepth: 0, TraceIndex: 1, AttackGIndex: 16, DefendGIndex: 18},
	{GIndex: 9, Depth: 3, IndexAtDepth: 1, TraceIndex: 3, AttackGIndex: 18},
	{GIndex: 10, Depth: 3, IndexAtDepth: 2, TraceIndex: 5, AttackGIndex: 20, DefendGIndex: 22},
	{GIndex: 11, Depth: 3, IndexAtDepth: 3, TraceIndex: 7, AttackGIndex: 22},
	{GIndex: 12, Depth: 3, IndexAtDepth: 4, TraceIndex: 9, AttackGIndex: 24, DefendGIndex: 26},
	{GIndex: 13, Depth: 3, IndexAtDepth: 5, TraceIndex: 11, AttackGIndex: 26},
	{GIndex: 14, Depth: 3, IndexAtDepth: 6, TraceIndex: 13, AttackGIndex: 28, DefendGIndex: 30},
	{GIndex: 15, Depth: 3, IndexAtDepth: 7, TraceIndex: 15, AttackGIndex: 30},

	{GIndex: 16, Depth: 4, IndexAtDepth: 0, TraceIndex: 0},
	{GIndex: 17, Depth: 4, IndexAtDepth: 1, TraceIndex: 1},
	{GIndex: 18, Depth: 4, IndexAtDepth: 2, TraceIndex: 2},
	{GIndex: 19, Depth: 4, IndexAtDepth: 3, TraceIndex: 3},
	{GIndex: 20, Depth: 4, IndexAtDepth: 4, TraceIndex: 4},
	{GIndex: 21, Depth: 4, IndexAtDepth: 5, TraceIndex: 5},
	{GIndex: 22, Depth: 4, IndexAtDepth: 6, TraceIndex: 6},
	{GIndex: 23, Depth: 4, IndexAtDepth: 7, TraceIndex: 7},
	{GIndex: 24, Depth: 4, IndexAtDepth: 8, TraceIndex: 8},
	{GIndex: 25, Depth: 4, IndexAtDepth: 9, TraceIndex: 9},
	{GIndex: 26, Depth: 4, IndexAtDepth: 10, TraceIndex: 10},
	{GIndex: 27, Depth: 4, IndexAtDepth: 11, TraceIndex: 11},
	{GIndex: 28, Depth: 4, IndexAtDepth: 12, TraceIndex: 12},
	{GIndex: 29, Depth: 4, IndexAtDepth: 13, TraceIndex: 13},
	{GIndex: 30, Depth: 4, IndexAtDepth: 14, TraceIndex: 14},
	{GIndex: 31, Depth: 4, IndexAtDepth: 15, TraceIndex: 15},
}

// TestGINConversions does To & From the generalized index on the treeNodesMaxDepth4 data
func TestGINConversions(t *testing.T) {
	for _, test := range treeNodesMaxDepth4 {
		from := NewPositionFromGIndex(test.GIndex)
		pos := NewPosition(test.Depth, test.IndexAtDepth)
		require.Equal(t, pos, from)
		to := pos.ToGIndex()
		require.Equal(t, test.GIndex, to.Uint64())
	}
}

// TestTraceIndex creates the position & then tests the trace index function on the treeNodesMaxDepth4 data
func TestTraceIndex(t *testing.T) {
	for _, test := range treeNodesMaxDepth4 {
		pos := NewPosition(test.Depth, test.IndexAtDepth)
		result := pos.TraceIndex(4)
		require.Equal(t, test.TraceIndex, result)
	}
}

func TestAttack(t *testing.T) {
	for _, test := range treeNodesMaxDepth4 {
		if test.AttackGIndex == 0 {
			continue
		}
		pos := NewPosition(test.Depth, test.IndexAtDepth)
		result := pos.Attack()
		require.Equalf(t, test.AttackGIndex, result.ToGIndex().Uint64(), "Attack from GIndex %v", pos.ToGIndex())
	}
}

func TestDefend(t *testing.T) {
	for _, test := range treeNodesMaxDepth4 {
		if test.DefendGIndex == 0 {
			continue
		}
		pos := NewPosition(test.Depth, test.IndexAtDepth)
		result := pos.Defend()
		require.Equalf(t, test.DefendGIndex, result.ToGIndex().Uint64(), "Defend from GIndex %v", pos.ToGIndex())
	}
}
