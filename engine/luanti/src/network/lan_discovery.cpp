// CindrixCraft: LAN discovery
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lan_discovery.h"
#include "network/address.h"
#include "exceptions.h"
#include "log.h"
#include "porting.h"
#include "util/string.h"
#include <cstdlib>

namespace lan
{

static const char MAGIC[] = "CXC1\n";
static const int MAX_PACKET = 512;
static const float ANNOUNCE_INTERVAL = 2.0f;
static const u64 ENTRY_TIMEOUT_MS = 8000;

static std::string clean(const std::string &s)
{
	std::string out;
	for (char c : s) {
		if (c == '\n' || c == '\r' || c == '\t')
			c = ' ';
		out.push_back(c);
	}
	if (out.size() > 80)
		out.resize(80);
	return out;
}

std::string serializePacket(const Info &info)
{
	std::string s = MAGIC;
	s += "name=" + clean(info.name) + "\n";
	s += "port=" + std::to_string(info.port) + "\n";
	s += "game=" + clean(info.game) + "\n";
	s += "players=" + std::to_string(info.players) + "\n";
	s += "max=" + std::to_string(info.max_players) + "\n";
	s += "version=" + clean(info.version) + "\n";
	return s;
}

bool parsePacket(const char *data, int size, Info &info)
{
	if (size < (int)sizeof(MAGIC) - 1 || size > MAX_PACKET)
		return false;
	std::string s(data, size);
	if (s.compare(0, sizeof(MAGIC) - 1, MAGIC) != 0)
		return false;

	bool got_port = false;
	size_t pos = sizeof(MAGIC) - 1;
	while (pos < s.size()) {
		size_t end = s.find('\n', pos);
		if (end == std::string::npos)
			end = s.size();
		std::string line = s.substr(pos, end - pos);
		pos = end + 1;

		size_t eq = line.find('=');
		if (eq == std::string::npos)
			continue;
		std::string key = line.substr(0, eq);
		std::string val = line.substr(eq + 1);
		if (key == "name") {
			info.name = val;
		} else if (key == "port") {
			long p = strtol(val.c_str(), nullptr, 10);
			if (p > 0 && p < 65536) {
				info.port = (u16)p;
				got_port = true;
			}
		} else if (key == "game") {
			info.game = val;
		} else if (key == "players") {
			info.players = (u32)strtoul(val.c_str(), nullptr, 10);
		} else if (key == "max") {
			info.max_players = (u32)strtoul(val.c_str(), nullptr, 10);
		} else if (key == "version") {
			info.version = val;
		}
	}
	return got_port;
}

/* Announcer */

bool Announcer::due(float dtime)
{
	m_timer += dtime;
	if (m_timer < ANNOUNCE_INTERVAL)
		return false;
	m_timer = 0.0f;
	return true;
}

void Announcer::send(const Info &info)
{
	if (m_socket_failed)
		return;
	try {
		if (!m_socket_ready) {
			if (!m_socket.init(false, true)) {
				m_socket_failed = true;
				warningstream << "LAN discovery: could not create socket" << std::endl;
				return;
			}
			m_socket.SetBroadcast(true);
			m_socket_ready = true;
		}
		std::string pkt = serializePacket(info);
		m_socket.Send(Address(255, 255, 255, 255, DISCOVERY_PORT),
				pkt.data(), (int)pkt.size());
	} catch (BaseException &e) {
		// Not fatal (no network, firewall...). Try again at the next interval.
		tracestream << "LAN discovery: announce failed: " << e.what() << std::endl;
	}
}

/* Listener */

void Listener::start()
{
	if (m_started || m_start_failed)
		return;
	try {
		m_socket = std::make_unique<UDPSocket>();
		if (!m_socket->init(false, true)) {
			m_socket.reset();
			m_start_failed = true;
			return;
		}
		m_socket->SetReuseAddr(true);
		m_socket->SetBroadcast(true);
		m_socket->Bind(Address(0, 0, 0, 0, DISCOVERY_PORT));
		m_socket->setTimeoutMs(0);
		m_started = true;
	} catch (BaseException &e) {
		m_socket.reset();
		m_start_failed = true;
		warningstream << "LAN discovery: cannot listen: " << e.what() << std::endl;
	}
}

void Listener::stop()
{
	if (!m_started && !m_start_failed)
		return;
	m_socket.reset();
	m_started = false;
	m_start_failed = false;
	m_entries.clear();
}

bool Listener::poll()
{
	if (!m_started)
		return false;

	bool changed = false;
	u64 now = porting::getTimeMs();

	char buf[MAX_PACKET + 1];
	for (int i = 0; i < 64; i++) {
		Address sender;
		int n;
		try {
			n = m_socket->Receive(sender, buf, MAX_PACKET);
		} catch (BaseException &) {
			break;
		}
		if (n <= 0)
			break;

		Info info;
		if (!parsePacket(buf, n, info))
			continue;
		std::string addr = sender.serializeString();
		std::string key = addr + ":" + std::to_string(info.port);

		auto it = m_entries.find(key);
		if (it == m_entries.end()) {
			changed = true;
		} else {
			const Info &old = it->second.info;
			if (old.name != info.name || old.players != info.players ||
					old.max_players != info.max_players || old.game != info.game)
				changed = true;
		}
		Entry e;
		e.address = addr;
		e.info = info;
		e.last_seen_ms = now;
		m_entries[key] = e;
	}

	for (auto it = m_entries.begin(); it != m_entries.end();) {
		if (now - it->second.last_seen_ms > ENTRY_TIMEOUT_MS) {
			it = m_entries.erase(it);
			changed = true;
		} else {
			++it;
		}
	}
	return changed;
}

std::vector<Entry> Listener::getServers() const
{
	std::vector<Entry> out;
	for (const auto &kv : m_entries)
		out.push_back(kv.second);
	return out;
}

Listener &listener()
{
	static Listener l;
	return l;
}

}
