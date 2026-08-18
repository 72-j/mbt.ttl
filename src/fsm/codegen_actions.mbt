///|
/// 生成动作分发函数
// fn emit_action_dispatch(ir : FsmIR) -> String {
//   // 收集所有用到的 action
//   let actions = []

//   for t in ir.transitions {
//     match t.action {
//       Some(action) =>
//         if !actions.contains(action.to_string()) {
//           actions.push(action.to_string())
//         }
//       None => ()
//     }
//   }

//   let code = StringBuilder::new()

//   if actions.is_empty() {
//     code <+ "///|\n"
//     code <+
//       "pub fn dispatch_action(_action: String, data: StateData) -> StateData { data }\n"
//   } else {
//     code <+ "///|\n"
//     code <+
//       "pub fn dispatch_action(action: String, data: StateData) -> StateData {\n"

//     code.write("  match action {\n")

//     for i = 0; i < actions.length(); i = i + 1 {
//       code <+ "    \""
//       code.write(actions[i])
//       code <+ "\" => data // TODO: implement\n"
//     }

//     code <+ "    _ => data\n"
//     code <+ "  }\n"
//     code <+ "}\n"
//   }

//   code.to_string()
// }
