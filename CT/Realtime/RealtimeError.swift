//
//  RealtimeError.swift
//  CT
//

nonisolated enum RealtimeError: Error {
    case invalidURL
    case httpStatus(Int)
    case decodeFailed(String)
    case allSourcesFailed
}
