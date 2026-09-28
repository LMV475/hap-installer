/*
 * Copyright (c) 2025 LMV475
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef hap_signer_tool_h
#define hap_signer_tool_h


int sign_hap(int argc, const char *argv[]);

#ifdef __cplusplus
extern "C"
{
#endif

    int unzip(const char *source, const char *fileName, const char *destination);

#ifdef __cplusplus
}
#endif
#endif

