'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { getUser, clearSession, apiFetch } from '../api';

export default function Navbar() {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUserState] = useState(null);

  useEffect(() => {
    const u = getUser();
    if (!u) {
      router.push('/login');
    } else {
      setUserState(u);
    }
  }, [router]);

  const handleLogout = async () => {
    try {
      await apiFetch('/auth/logout', { method: 'POST' });
    } catch (e) {
      console.error('Logout error:', e);
    }
    clearSession();
    router.push('/login');
  };

  if (!user) return null;

  return (
    <header className="navbar" id="app-navbar">
      <Link href="/dashboard" className="logo" id="nav-logo">
        NF-Bank
      </Link>
      <nav className="nav-links" id="nav-menu">
        <Link 
          href="/dashboard" 
          className={pathname === '/dashboard' ? 'active' : ''}
          id="nav-link-dashboard"
        >
          Dashboard
        </Link>
        <Link 
          href="/transfer" 
          className={pathname === '/transfer' ? 'active' : ''}
          id="nav-link-transfer"
        >
          Chuyển tiền
        </Link>
        <Link 
          href="/profile" 
          className={pathname === '/profile' ? 'active' : ''}
          id="nav-link-profile"
        >
          Hồ sơ
        </Link>
        <Link 
          href="/change-password" 
          className={pathname === '/change-password' ? 'active' : ''}
          id="nav-link-change-password"
        >
          Đổi mật khẩu
        </Link>

      </nav>
      <div className="nav-user" id="nav-user-section">
        <span className="nav-user-email" id="nav-user-email">
          {user.full_name || user.fullName || user.email}
        </span>
        <button 
          onClick={handleLogout} 
          className="btn btn-secondary" 
          style={{ padding: '8px 16px', fontSize: '0.85rem', borderRadius: '8px' }}
          id="nav-logout-btn"
        >
          Đăng xuất
        </button>
      </div>
    </header>
  );
}
