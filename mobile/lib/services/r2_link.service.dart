import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:openapi/api.dart';

class R2LinkService {
  final ApiService _apiService;

  R2LinkService(this._apiService);

  Future<List<R2LinkResponseDto>> createLinks({
    required List<String> assetIds,
    required String expiresIn,
  }) async {
    final client = NetworkRepository.client;
    final basePath = _apiService.apiClient.basePath;
    final uri = Uri.parse('$basePath/api/r2-links');

    final response = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assetIds': assetIds,
        'expiresIn': expiresIn,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create R2 links: ${response.statusCode}');
    }

    final list = (jsonDecode(response.body) as List)
        .map((e) => R2LinkResponseDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<R2LinkResponseDto>> getLinks() async {
    final client = NetworkRepository.client;
    final basePath = _apiService.apiClient.basePath;
    final uri = Uri.parse('$basePath/api/r2-links');

    final response = await client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to get R2 links: ${response.statusCode}');
    }

    final list = (jsonDecode(response.body) as List)
        .map((e) => R2LinkResponseDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<void> revokeLink(String id) async {
    final client = NetworkRepository.client;
    final basePath = _apiService.apiClient.basePath;
    final uri = Uri.parse('$basePath/api/r2-links/$id');

    final response = await client.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to revoke R2 link: ${response.statusCode}');
    }
  }

  Future<void> revokeLinks(List<String> ids) async {
    final client = NetworkRepository.client;
    final basePath = _apiService.apiClient.basePath;
    final uri = Uri.parse('$basePath/api/r2-links');

    final response = await client.delete(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ids': ids}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to revoke R2 links: ${response.statusCode}');
    }
  }
}

class R2LinkResponseDto {
  final String id;
  final String assetId;
  final String url;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? revokedAt;

  R2LinkResponseDto({
    required this.id,
    required this.assetId,
    required this.url,
    this.expiresAt,
    required this.createdAt,
    this.revokedAt,
  });

  factory R2LinkResponseDto.fromJson(Map<String, dynamic> json) {
    return R2LinkResponseDto(
      id: json['id'] as String,
      assetId: json['assetId'] as String,
      url: json['url'] as String,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'] as String)
          : null,
    );
  }
}