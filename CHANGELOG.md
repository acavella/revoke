# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- Major redevelopment effort towards version 2.0.0.
- Code modularity, functions built into individual external modules.
- Read CRL data to database.
- OCSP responder functionality.
- Automated installation via script and package manager (RPM).
- Guided configuration script.
- Script and configuration validation.
- Built in help menu with example commands.
- Improved documentation; use cases, installation, configuration, etc...
- Updated project website.

## [1.0.1] - 2019-04-02
### Removed
- OpenSSL CRL validation system too complex, requires rework.

## [1.0.0] - 2019-04-01
### Added
- Initial public release.
- OpenSSL CRL validation.

## [0.2.0-alpha] - 2019-03-30
### Added
- Gateway and network validation.

### Changed
- Logging format improved and removed from CLI

## [0.1.0-alpha] - 2019-03-27
### Added
- Initial rapid development version
