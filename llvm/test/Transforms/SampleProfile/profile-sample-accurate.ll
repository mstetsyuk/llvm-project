; RUN: opt < %s -passes=sample-profile -sample-profile-file=%S/Inputs/profsampleacc.extbinary.afdo -profile-summary-cutoff-hot=900000 -profile-sample-accurate -S | FileCheck %s --check-prefix=CALL_SUM_IS_HOT
; RUN: opt < %s -passes=sample-profile -sample-profile-file=%S/Inputs/profsampleacc.extbinary.afdo -profile-summary-cutoff-hot=900000 -profile-sample-accurate -S | FileCheck %s --check-prefix=CALL_SUM_IS_HOT

; RUN: llvm-profdata merge -sample -extbinary -prof-sym-list=%S/Inputs/profile-symbol-list.text %S/Inputs/profsampleacc.extbinary.afdo -o %t.symlist.afdo
; RUN: opt < %s -passes=sample-profile -sample-profile-file=%t.symlist.afdo -profile-summary-cutoff-hot=600000 -profile-accurate-for-symsinlist -S | FileCheck %s --check-prefix=PROFSYMLIST
; RUN: opt < %s -passes=sample-profile -sample-profile-file=%t.symlist.afdo -profile-accurate-for-symsinlist -profile-symbol-list-cutoff=2 -S | FileCheck %s --check-prefix=PSLCUTOFF2
; RUN: opt < %s -passes=sample-profile -sample-profile-file=%t.symlist.afdo -profile-accurate-for-symsinlist -profile-symbol-list-cutoff=3 -S | FileCheck %s --check-prefix=PSLCUTOFF3
;
; If -profile-accurate-for-symsinlist and -profile-sample-accurate both present,
; -profile-sample-accurate will override -profile-accurate-for-symsinlist.
; RUN: opt < %s -passes=sample-profile -sample-profile-file=%S/Inputs/profsampleacc.extbinary.afdo -profile-summary-cutoff-hot=900000 -profile-sample-accurate -profile-accurate-for-symsinlist -S | FileCheck %s --check-prefix=CALL_SUM_IS_HOT
; RUN: opt < %s -passes=sample-profile -sample-profile-file=%S/Inputs/profsampleacc.extbinary.afdo -profile-summary-cutoff-hot=900000 -profile-sample-accurate -profile-accurate-for-symsinlist -S | FileCheck %s --check-prefix=CALL_SUM_IS_HOT
;
; Original C++ test case
;
; #include <stdio.h>
;
; int sum(int x, int y) {
;   return x + y;
; }
;
; int main() {
;   int s, i = 0;
;   while (i++ < 20000 * 20000)
;     if (i != 100) s = sum(i, s); else s = 30;
;   printf("sum is %d\n", s);
;   return 0;
; }
;
@.str = private unnamed_addr constant [11 x i8] c"sum is %d\0A\00", align 1

; Check _Z3sumii's function entry count will be 0 when
; profile-sample-accurate is enabled.
; CALL_SUM_IS_HOT: define i32 @_Z3sumii{{.*}}!prof ![[ZERO_ID:[0-9]+]]
;
; Check _Z3sumii's function entry count will be nonzero when
; profile-sample-accurate is enabled because the callsite is warm and not
; inlined so its function entry count is adjusted to nonzero.
; CALL_SUM_IS_WARM: define i32 @_Z3sumii{{.*}}!prof ![[NONZERO_ID:[0-9]+]]
;
; Check _Z3sumii's function entry count will be initialized to -1 when
; profile-accurate-for-profsymlist is enabled and _Z3sumii exists in the
; profile symbol list because it also shows up in the profile as inline
; instance.
; PROFSYMLIST: define i32 @_Z3sumii{{.*}}!prof ![[UNKNOWN_ID:[0-9]+]]
;
; Function Attrs: nounwind uwtable
define i32 @_Z3sumii(i32 %x, i32 %y) #0 !dbg !4 {
entry:
  %x.addr = alloca i32, align 4
  %y.addr = alloca i32, align 4
  store i32 %x, i32* %x.addr, align 4
  store i32 %y, i32* %y.addr, align 4
  %0 = load i32, i32* %x.addr, align 4, !dbg !11
  %1 = load i32, i32* %y.addr, align 4, !dbg !11
  %add = add nsw i32 %0, %1, !dbg !11
  ret i32 %add, !dbg !11
}

; Check -profile-symbol-list-cutoff=3 will include _Z3toov into profile
; symbol list and -profile-symbol-list-cutoff=2 will not.
; PSLCUTOFF2: define i32 @_Z3toov{{.*}}!prof ![[TOO_ID:[0-9]+]]
; PSLCUTOFF3: define i32 @_Z3toov{{.*}}!prof ![[TOO_ID:[0-9]+]]
define i32 @_Z3toov(i32 %x, i32 %y) #0 {
entry:
  %add = add nsw i32 %x, %y
  ret i32 %add
}

; Function Attrs: uwtable
define i32 @main() #0 !dbg !7 {
entry:
  %retval = alloca i32, align 4
  %s = alloca i32, align 4
  %i = alloca i32, align 4
  store i32 0, i32* %retval
  store i32 0, i32* %i, align 4, !dbg !12
  br label %while.cond, !dbg !13

while.cond:                                       ; preds = %if.end, %entry
  %0 = load i32, i32* %i, align 4, !dbg !14
  %inc = add nsw i32 %0, 1, !dbg !14
  store i32 %inc, i32* %i, align 4, !dbg !14
  %cmp = icmp slt i32 %0, 400000000, !dbg !14
  br i1 %cmp, label %while.body, label %while.end, !dbg !14

while.body:                                       ; preds = %while.cond
  %1 = load i32, i32* %i, align 4, !dbg !16
  %cmp1 = icmp ne i32 %1, 100, !dbg !16
  br i1 %cmp1, label %if.then, label %if.else, !dbg !16

; With the hot cutoff being set to 600000, the inline instance of _Z3sumii
; in main is neither hot nor cold. Check it won't be inlined when
; profile-sample-accurate is enabled.
; CALL_SUM_IS_WARM: if.then:
; CALL_SUM_IS_WARM: call i32 @_Z3sumii
; CALL_SUM_IS_WARM: if.else:
;
; With the hot cutoff being set to 900000, the inline instance of _Z3sumii
; in main is hot. Check the callsite of _Z3sumii will be inlined when
; profile-sample-accurate is enabled.
; CALL_SUM_IS_HOT: if.then:
; CALL_SUM_IS_HOT-NOT: call i32 @_Z3sumii
; CALL_SUM_IS_HOT: if.else:
;
; Check _Z3sumii will be inlined when profile-accurate-for-profsymlist is
; enabled
; PROFSYMLIST: if.then:
; PROFSYMLIST-NOT: call i32 @_Z3sumii
; PROFSYMLIST: if.else:
if.then:                                          ; preds = %while.body
  %2 = load i32, i32* %i, align 4, !dbg !18
  %3 = load i32, i32* %s, align 4, !dbg !18
  %call = call i32 @_Z3sumii(i32 %2, i32 %3), !dbg !18
  store i32 %call, i32* %s, align 4, !dbg !18
  br label %if.end, !dbg !18

if.else:                                          ; preds = %while.body
  store i32 30, i32* %s, align 4, !dbg !20
  br label %if.end

if.end:                                           ; preds = %if.else, %if.then
  br label %while.cond, !dbg !22

while.end:                                        ; preds = %while.cond
  %4 = load i32, i32* %s, align 4, !dbg !24
  %call2 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str, i32 0, i32 0), i32 %4), !dbg !24
  ret i32 0, !dbg !25
}

declare i32 @printf(i8*, ...) #2

attributes #0 = { "use-sample-profile" }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!8, !9}
!llvm.ident = !{!10}

; CALL_SUM_IS_HOT: ![[ZERO_ID]] = !{!"function_entry_count", i64 0}
; CALL_SUM_IS_WARM: ![[NONZERO_ID]] = !{!"function_entry_count", i64 5179}
; PROFSYMLIST: ![[UNKNOWN_ID]] = !{!"function_entry_count", i64 -1}
; PSLCUTOFF2: ![[TOO_ID]] = !{!"function_entry_count", i64 -1}
; PSLCUTOFF3: ![[TOO_ID]] = !{!"function_entry_count", i64 0}
!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, producer: "clang version 3.5 ", isOptimized: false, emissionKind: NoDebug, file: !1, enums: !2, retainedTypes: !2, globals: !2, imports: !2)
!1 = !DIFile(filename: "calls.cc", directory: ".")
!2 = !{}
!4 = distinct !DISubprogram(name: "sum", line: 3, isLocal: false, isDefinition: true, virtualIndex: 6, flags: DIFlagPrototyped, isOptimized: false, unit: !0, scopeLine: 3, file: !1, scope: !5, type: !6, retainedNodes: !2)
!5 = !DIFile(filename: "calls.cc", directory: ".")
!6 = !DISubroutineType(types: !2)
!7 = distinct !DISubprogram(name: "main", line: 7, isLocal: false, isDefinition: true, virtualIndex: 6, flags: DIFlagPrototyped, isOptimized: false, unit: !0, scopeLine: 7, file: !1, scope: !5, type: !6, retainedNodes: !2)
!8 = !{i32 2, !"Dwarf Version", i32 4}
!9 = !{i32 1, !"Debug Info Version", i32 3}
!10 = !{!"clang version 3.5 "}
!11 = !DILocation(line: 4, scope: !4)
!12 = !DILocation(line: 8, scope: !7)
!13 = !DILocation(line: 9, scope: !7)
!14 = !DILocation(line: 9, scope: !15)
!15 = !DILexicalBlockFile(discriminator: 2, file: !1, scope: !7)
!16 = !DILocation(line: 10, scope: !17)
!17 = distinct !DILexicalBlock(line: 10, column: 0, file: !1, scope: !7)
!18 = !DILocation(line: 10, scope: !19)
!19 = !DILexicalBlockFile(discriminator: 2, file: !1, scope: !17)
!20 = !DILocation(line: 10, scope: !21)
!21 = !DILexicalBlockFile(discriminator: 4, file: !1, scope: !17)
!22 = !DILocation(line: 10, scope: !23)
!23 = !DILexicalBlockFile(discriminator: 6, file: !1, scope: !17)
!24 = !DILocation(line: 11, scope: !7)
!25 = !DILocation(line: 12, scope: !7)
