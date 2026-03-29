//

/// Print log only in debug.
/// - Parameter data: log information data.
func printLog<T>(_ data: T?) {
#if DEBUG
  if let data = data {
    print(data)
  }
#endif
}
