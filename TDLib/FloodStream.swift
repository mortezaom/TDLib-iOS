public class FloodStream: Stream<Date?> {
    private let queue: DispatchQueue = DispatchQueue(label: "file_stream", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var lastId: Int?
    private let regex = (try? NSRegularExpression(pattern: "\\[id:(\\d+?)].+?\\[total_timeout:([\\d\\.]+)]", options: []))!
    init(logPath: String) {
        super.init()
        let fileSystemRepresentation = (logPath as NSString).fileSystemRepresentation

        // Obtain a descriptor from the file system
        let fileDescriptor = open(fileSystemRepresentation, O_EVTONLY)

        // Create our dispatch source
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                               eventMask: .write,
                                                               queue: self.queue)

        // Assign the closure to it, and resume it to start observing
        source.setEventHandler(handler: { [weak self] in
            do {
                let log = try String(contentsOfFile: logPath)
                for line in log.components(separatedBy: .newlines).reversed() {
                    let string = (line as NSString)
                    if let match = self?.regex.firstMatch(in: line, options: [], range: NSMakeRange(0, string.length)),
                        match.numberOfRanges >= 3,
                        let id = Int(string.substring(with: match.range(at: 1))) {
                        if id == self?.lastId {
                            return
                        } else {
                            let delay = Double(string.substring(with: match.range(at: 2))) ?? 0
                            self?.lastId = id
                            self?.current = Date(timeIntervalSinceNow: delay)
                        }
                    }
                }
            } catch {

            }
        })
        source.resume()
        self.source = source
    }
}

