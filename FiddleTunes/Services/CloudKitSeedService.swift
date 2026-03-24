// FiddleTunes/Services/CloudKitSeedService.swift
import CloudKit
import Foundation
import SwiftData

/// Manages seed audio files stored in CloudKit's public database.
///
/// Upload (DEBUG only): Call `uploadIfNeeded()` once from the Simulator to push
/// bundled audio files into CloudKit. After confirming the upload worked, delete
/// the Audio directory from the bundle.
///
/// Download: Call `downloadMissingAudio(container:)` on every launch. It finds
/// Tune objects whose audioFileName file is absent from Documents and fetches
/// the matching CKAsset from the public database.
enum CloudKitSeedService {
    private static let containerID = "iCloud.com.iancurry.fiddletunes"
    private static let recordType  = "SeedAudio"

    // MARK: - Download

    /// Kicks off a background task that downloads any missing seed audio files.
    static func downloadMissingAudio(container: ModelContainer) {
        Task.detached(priority: .background) {
            await fetchAndSave(container: container)
        }
    }

    private static func fetchAndSave(container: ModelContainer) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Collect filenames that are expected but not yet on disk
        let context = ModelContext(container)
        let tunes = (try? context.fetch(FetchDescriptor<Tune>())) ?? []
        let needed: [String] = tunes.compactMap { tune in
            guard let fn = tune.audioFileName else { return nil }
            return FileManager.default.fileExists(atPath: docs.appendingPathComponent(fn).path) ? nil : fn
        }
        guard !needed.isEmpty else { return }

        let publicDB = CKContainer(identifier: containerID).publicCloudDatabase
        // audioFileName is queryable; fetch all records that have one set.
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "audioFileName != %@", ""))

        do {
            let (results, _) = try await publicDB.records(matching: query,
                                                          desiredKeys: ["audioFileName", "audioFile"])
            for (_, result) in results {
                guard let record    = try? result.get(),
                      let fileName  = record["audioFileName"] as? String,
                      let asset     = record["audioFile"]     as? CKAsset,
                      let assetURL  = asset.fileURL else { continue }

                let destURL = docs.appendingPathComponent(fileName)
                guard !FileManager.default.fileExists(atPath: destURL.path) else { continue }
                try? FileManager.default.copyItem(at: assetURL, to: destURL)
                print("CloudKitSeedService: saved \(fileName)")
            }
        } catch {
            print("CloudKitSeedService: download error: \(error)")
        }
    }

    // MARK: - Upload (DEBUG only — run once from Simulator, then delete Audio from bundle)

    #if DEBUG
    /// Uploads bundled audio files to the CloudKit public database if the
    /// SeedAudio record type is empty. Safe to call on every DEBUG launch.
    static func uploadBundledAudioIfNeeded() {
        Task.detached(priority: .background) {
            await performUpload()
        }
    }

    private struct SeedEntry: Decodable {
        let audioFileName: String?
    }

    private static func performUpload() async {
        let publicDB = CKContainer(identifier: containerID).publicCloudDatabase

        // Skip if records already exist
        let probe = CKQuery(recordType: recordType, predicate: NSPredicate(format: "audioFileName != %@", ""))
        if let (existing, _) = try? await publicDB.records(matching: probe, desiredKeys: []),
           !existing.isEmpty {
            print("CloudKitSeedService: \(existing.count) records already in public DB — skipping upload")
            return
        }

        guard let jsonURL = Bundle.main.url(forResource: "seed_tunes", withExtension: "json"),
              let data    = try? Data(contentsOf: jsonURL),
              let seeds   = try? JSONDecoder().decode([SeedEntry].self, from: data)
        else { return }

        var records: [CKRecord] = []
        for seed in seeds {
            guard let audioFileName = seed.audioFileName,
                  let audioURL = Bundle.main.url(
                    forResource: (audioFileName as NSString).deletingPathExtension,
                    withExtension: (audioFileName as NSString).pathExtension
                  ) else { continue }

            let record = CKRecord(recordType: recordType)
            record["audioFileName"] = audioFileName as CKRecordValue
            record["audioFile"]     = CKAsset(fileURL: audioURL)
            records.append(record)
        }

        guard !records.isEmpty else {
            print("CloudKitSeedService: no bundled audio files found — has the Audio directory been removed?")
            return
        }

        // Upload in batches of 20 (CloudKit limit per operation)
        let batches = stride(from: 0, to: records.count, by: 20).map {
            Array(records[$0..<min($0 + 20, records.count)])
        }

        for batch in batches {
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    let op = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
                    op.savePolicy = .ifServerRecordUnchanged
                    op.qualityOfService = .utility
                    op.modifyRecordsResultBlock = { result in
                        cont.resume(with: result)
                    }
                    publicDB.add(op)
                }
                print("CloudKitSeedService: uploaded batch of \(batch.count)")
            } catch {
                print("CloudKitSeedService: upload batch failed: \(error)")
            }
        }
        print("CloudKitSeedService: upload complete — \(records.count) records saved")
    }
    #endif
}
