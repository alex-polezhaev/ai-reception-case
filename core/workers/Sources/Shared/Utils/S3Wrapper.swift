// S3Wrapper: thin wrapper over SotoS3 for object storage access.
import Foundation
import SotoS3

public final class S3Wrapper: Sendable {
    private let client: S3

    public init() throws {
        let accessKey: String = try env("AWS_ACCESS_KEY_ID", as: String.self)
        let secretKey: String = try env("AWS_SECRET_ACCESS_KEY", as: String.self)
        let region = Region(awsRegionName: try env("S3_REGION", as: String.self))
        let endpoint = try env("S3_ENDPOINT", as: String.self)

        let awsClient = AWSClient(
            credentialProvider: .static(accessKeyId: accessKey, secretAccessKey: secretKey),
            httpClientProvider: .createNew
        )

        self.client = S3(client: awsClient, region: region, endpoint: endpoint)
    }

    deinit {
        try? client.client.syncShutdown()
    }

    public func upload(bucket: String, key: String, data: Data) async throws {
        let putObjectRequest = S3.PutObjectRequest(
            body: .data(data),
            bucket: bucket,
            key: key
        )

        _ = try await client.putObject(putObjectRequest)
    }

    public func download(bucket: String, key: String) async throws -> Data {
        let getObjectRequest = S3.GetObjectRequest(bucket: bucket, key: key)
        let response = try await client.getObject(getObjectRequest)

        guard let body = response.body else {
            throw NSError(domain: "S3", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data"])
        }

        return body.asData() ?? Data()
    }

    public func delete(bucket: String, key: String) async throws {
        let deleteObjectRequest = S3.DeleteObjectRequest(bucket: bucket, key: key)
        _ = try await client.deleteObject(deleteObjectRequest)
    }

    public func signedUrl(
        bucket: String,
        key: String,
        method: HTTPMethod,
        expiresInSec: Int64,
    ) async throws -> URL {
        let url = URL(string: "\(client.config.endpoint)/\(bucket)/\(key)")!

        return try await client.signURL(
            url: url,
            httpMethod: method,
            expires: .seconds(expiresInSec),
        )
    }
}
