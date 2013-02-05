#!/bin/bash
#
# requires:
#   bash
#

## include files

. ${BASH_SOURCE[0]%/*}/helper_shunit2.sh

## variables

declare namespace=${BASH_SOURCE[0]##*/}; namespace=${namespace##t.}; namespace=${namespace%%.sh}

## functions

### help

function test_index() {
  step_base_index
}

function test_show() {
  step_base_show_ids
}

## shunit2

. ${shunit2_file}
