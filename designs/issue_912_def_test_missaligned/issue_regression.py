# Copyright 2022 Arman Avetisyan
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys


with open(sys.argv[1] + "/openlane.log") as f:
    content = f.read()
    if content.find(
        "Pin coordinate 9861 for pin manufacturing_grid_missaligned_pin does not match the manufacturing grid"
    ) and content.find(
        "Pin coordinate 10141 for pin manufacturing_grid_missaligned_pin does not match the manufacturing grid"
    ):
        sys.exit(0)
    else:
        sys.exit("Didn't match the log")
