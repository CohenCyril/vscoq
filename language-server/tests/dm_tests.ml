open Base
open Dm
open Lsp

let init_state = Vernacstate.freeze_full_state ~marshallable:false

let init text =
  DocumentManager.init init_state ~opts:[] ~uri:"doc" ~text

let edit_text st ~start ~stop ~text =
  let doc = DocumentManager.Internal.document st in
  let start = Document.position_of_loc doc start in
  let stop = Document.position_of_loc doc stop in
  let range = LspData.Range.{ start; stop } in
  DocumentManager.apply_text_edits st [(range, text)]

let insert_text st ~loc ~text =
  edit_text st ~start:loc ~stop:loc ~text

let rec handle_events (events : DocumentManager.events) st =
  match events with
  | [] -> st
  | _ ->
    Caml.flush_all ();
    let (ready, remaining) = Sel.wait events in
    let rec loop new_events events st =
      match events with
      | [] -> st, new_events
      | ev :: events ->
        let st, new_events = match DocumentManager.handle_event ev st with
        | None, events' -> st, new_events@events'
        | Some st, events' -> st, new_events@events'
        in
        loop new_events events st
    in
    let st, new_events = loop [] ready st in
    handle_events (remaining@new_events) st

let check_no_diag st =
  let diagnostics = DocumentManager.diagnostics st in
  [%test_pred: LspData.diagnostic list] List.is_empty diagnostics

let%test_unit "parse.init" =
  let st, events = init "Definition x := true. Definition y := false." in
  let st = DocumentManager.validate_document st in
  [%test_eq: int] (Document.end_loc @@ DocumentManager.Internal.document st) 44;
  let sentences = Document.sentences @@ DocumentManager.Internal.document st in
  let positions = Stdlib.List.map (fun s -> s.Document.start) sentences in
  [%test_eq: int list] positions [ 0; 22 ];
  check_no_diag st

let%test_unit "parse.insert" =
  let st, events = init "Definition x := true. Definition y := false." in
  let st = insert_text st ~loc:0 ~text:"Definition z := 0. " in
  let st = DocumentManager.validate_document st in
  let sentences = Document.sentences @@ DocumentManager.Internal.document st in
  let positions = Stdlib.List.map (fun s -> s.Document.start) sentences in
  [%test_eq: int list] positions [ 0; 19; 41 ];
  check_no_diag st

let%test_unit "parse.squash" =
  let st, events = init "Definition x := true. Definition y := false. Definition z := 0." in
  let st = edit_text st ~start:20 ~stop:21 ~text:"" in
  let st = DocumentManager.validate_document st in
  let sentences = Document.sentences @@ DocumentManager.Internal.document st in
  let start_positions = Stdlib.List.map (fun s -> s.Document.start) sentences in
  let stop_positions = Stdlib.List.map (fun s -> s.Document.stop) sentences in
  [%test_eq: int list] start_positions [ 0; 44 ];
  [%test_eq: int list] stop_positions [ 43; 62 ]

let%test_unit "parse.error_recovery" =
  let st, events = init "## . Definition x := true. !! . Definition y := false." in
  let st = DocumentManager.validate_document st in
  let sentences = Document.sentences @@ DocumentManager.Internal.document st in
  let start_positions = Stdlib.List.map (fun s -> s.Document.start) sentences in
  [%test_eq: int list] start_positions [ 0; 5; 26; 32 ]

let%test_unit "parse.extensions" =
  let st, events = init "Notation \"## x\" := x (at level 0). Definition f (x : nat) := ##xx." in
  let st = DocumentManager.validate_document st in
  let sentences = Document.sentences @@ DocumentManager.Internal.document st in
  let start_positions = Stdlib.List.map (fun s -> s.Document.start) sentences in
  [%test_eq: int list] start_positions [ 0; 35 ];
  check_no_diag st

  (*
let%test_unit "exec.init" =
  let st, events = init "Definition x := true. Definition y := false." in
  let st = DocumentManager.validate_document st in
  let st, events = DocumentManager.interpret_to_end st in
  let st = handle_events events st in
  let ranges = (DocumentManager.executed_ranges st).checked in
  let positions = Stdlib.List.map (fun s -> s.LspData.Range.start.char) ranges in
  check_no_diag st;
  [%test_eq: int list] positions [ 0; 22 ]

let%test_unit "exec.insert" =
  let st, events = init "Definition x := true. Definition y := false." in
  (* let st = handle_events events st in *)
  let st = DocumentManager.validate_document st in
  let st, events = DocumentManager.interpret_to_end st in
  let st = insert_text st ~loc:0 ~text:"Definition z := 0. " in
  let st = DocumentManager.validate_document st in
  let st, events = DocumentManager.interpret_to_end st in
  let ranges = (DocumentManager.executed_ranges st).checked in
  let positions = Stdlib.List.map (fun s -> s.LspData.Range.start.char) ranges in
  check_no_diag st;
  [%test_eq: int list] positions [ 0; 22 ]
  *)