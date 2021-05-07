

; one non-zero offset
define i1 @caller1(i32* %x) {
; CHECK-LABEL: @caller1(
; CHECK-NEXT:    [[TMP:%.*]] = getelementptr i32, i32* [[X:%.*]], i32 1
; CHECK-NEXT:    ret i1 false
;

  %tmp = getelementptr i32, i32* %x, i32 1
  %null_check = icmp eq i8* %x, null
  ret i1 %null_check
}

; one zero offset
define i1 @caller2(i32* %x) {
; CHECK-LABEL: @caller2(
; CHECK-NEXT:    [[TMP:%.*]] = getelementptr i32, i32* [[X:%.*]], i32 0
; CHECK-NEXT:    ret i1 false
;

  %tmp = getelementptr i32, i32* %x, i32 0
  %null_check = icmp eq i32* %x, null
  ret i1 %null_check
}

%MyStruct = type { i32, i32, [3 x i32]}

; multiple non-zero offsets
define i1 @caller3(%MyStruct* %x) {
; CHECK-LABEL: @caller3(
; CHECK-NEXT:    [[TMP:%.*]] = getelementptr %MyStruct, %MyStruct* [[X:%.*]], i32 0, i32 2, i32 1
; CHECK-NEXT:    ret i1 false
;

  %tmp = getelementptr %MyStruct, %MyStruct* %x, i32 0, i32 2, i32 1
  %null_check = icmp eq i32* %x, null
  ret i1 %null_check
}


; multiple zero offsets
define i1 @caller4(%MyStruct* %x) {
; CHECK-LABEL: @caller4(
; CHECK-NEXT:    [[TMP:%.*]] = getelementptr %MyStruct, %MyStruct* [[X:%.*]], i32, i32 0, i32 0, i32 0
; CHECK-NEXT:    ret i1 false
;

  %tmp = getelementptr %MyStruct, %MyStruct* %x, i32 0, i32 0, i32 0
  %null_check = icmp eq i32* %x, null
  ret i1 %null_check
}


; GEP call does not dominate the null check, so make sure nothing changes
define i32 @caller5(i32* %x) {
; CHECK-LABEL: @caller5(
; CHECK-NEXT:    [[NULL_CHECK:%.*]] = icmp eq i32* [[X:%.*]], null
; CHECK-NEXT:    br i1 [[NULL_CHECK]], label [[T:%.*]], label [[F:%.*]]
; CHECK:       t:
; CHECK-NEXT:    ret i1 [[NULL_CHECK]]
; CHECK:       f:
; CHECK-NEXT:    [[RES:%.*]] = getelementptr i32, i32* [[X]], i32 1
; CHECK-NEXT:    ret i32 [[RES]]

  %null_check = icmp eq i32* %x, null
  br i1 %null_check, label %t, label %f
t:
  ret i1 %null_check
f:
  %res = getelementptr i32, i32* %x, i32 1
  ret i32 %res
}


; Make sure null-check is not removed if store happened after the check
define i32 @caller6(i32* %x) {
; CHECK-LABEL: @caller6(
; CHECK-NEXT:  :
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr i32, i32* [[X:%.*]], i32 1
; CHECK-NEXT:    [[NULL_CHECK:%.*]] = icmp eq i32* %1, null
; CHECK-NEXT:    br i1 [[NULL_CHECK]], label [[RETURN:%.*]], label [[IF.END:%.*]]
; CHECK:       IF_END:
; CHECK_NEXT:    store i32 7, i32* [[TMP1]]
; CHECK_NEXT:    br label [[RETURN]]
; CHECK:       RETURN:
; CHECK-NEXT:    [[RETVAL_0:%.*]] = phi i32* [ [[TMP1]], IF_END ], [ null, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret i32* [[RETVAL_0]]


entry:
  %1 = getelementptr i32, i32* %x, i32 1
  %null_check = icmp eq i32* %1, null
  br i1 %null_check, label %return, label %if.end

if.end:
  store i32 7, i32* %1
  br label %return
return:
  %retval.0 = phi i32* [ %1, %if.end ], [ null, %entry ]
  ret i32* %retval.0
}


