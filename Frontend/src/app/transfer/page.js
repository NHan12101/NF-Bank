'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getUser } from '../api';
import Navbar from '../components/Navbar';
import { RecaptchaVerifier, signInWithPhoneNumber } from 'firebase/auth';
import { auth } from '../firebase';

export default function TransferPage() {
  const router = useRouter();
  const [accounts, setAccounts] = useState([]);
  const [receiverAccount, setReceiverAccount] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [successData, setSuccessData] = useState(null);

  // States for OTP Modal
  const [showOtpModal, setShowOtpModal] = useState(false);
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [confirmationResult, setConfirmationResult] = useState(null);
  const [otpLoading, setOtpLoading] = useState(false);
  const [otpError, setOtpError] = useState('');
  const [userPhone, setUserPhone] = useState('');

  const inputsRef = useRef([]);

  useEffect(() => {
    async function fetchAccounts() {
      try {
        const res = await apiFetch('/accounts');
        const data = await res.json();
        if (res.ok && data.success) {
          setAccounts(data.data || []);

          // Set default description
          const u = getUser();
          if (u) {
            setDescription(`${u.fullName || u.full_name || 'User'} chuyen tien`);
          }
        } else {
          setError(data.message || 'Không thể tải thông tin tài khoản nguồn.');
        }
      } catch (err) {
        setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
      }
    }
    fetchAccounts();
  }, []);

  const handleTransferSubmit = async (e) => {
    e.preventDefault();
    setError('');

    const amountVal = parseInt(amount, 10);
    if (isNaN(amountVal) || amountVal <= 0) {
      setError('Số tiền chuyển khoản phải lớn hơn 0.');
      return;
    }

    // Mở OTP Modal
    setShowOtpModal(true);
    setOtp(['', '', '', '', '', '']);
    setOtpError('');
    setOtpLoading(true);

    // Tìm số điện thoại của người dùng từ sessionStorage hoặc tải từ profile
    let phone = '';
    const u = getUser();
    if (u) {
      phone = u.phone;
    }

    if (!phone) {
      // Gọi API lấy profile nếu chưa có phone trong sessionStorage
      try {
        const profileRes = await apiFetch('/users/profile');
        const profileData = await profileRes.json();
        if (profileRes.ok && profileData.success && profileData.data.phone) {
          phone = profileData.data.phone;
          setUserPhone(phone);
          // Lưu lại vào sessionStorage
          const updatedUser = u ? { ...u, phone } : { phone };
          setUser(updatedUser);
        }
      } catch (err) {
        console.error("Lấy thông tin profile thất bại:", err);
      }
    } else {
      setUserPhone(phone);
    }

    if (!phone) {
      setOtpError('Không tìm thấy số điện thoại liên kết của tài khoản. Vui lòng kiểm tra lại profile.');
      setOtpLoading(false);
      return;
    }

    sendTransferOtp(phone);
  };

  const formatPhoneForFirebase = (phoneNum) => {
    if (!phoneNum) return '';
    let cleaned = phoneNum.replace(/\D/g, '');
    if (cleaned.startsWith('0')) {
      return '+84' + cleaned.slice(1);
    }
    if (cleaned.startsWith('84')) {
      return '+' + cleaned;
    }
    return '+' + cleaned;
  };

  useEffect(() => {
    return () => {
      if (window.transferRecaptchaVerifier) {
        try {
          window.transferRecaptchaVerifier.clear();
        } catch (e) { }
        window.transferRecaptchaVerifier = null;
      }
    };
  }, []);

  const sendTransferOtp = async (phoneNum) => {
    setOtpLoading(true);
    setOtpError('');
    try {
      if (window.transferRecaptchaVerifier) {
        try {
          window.transferRecaptchaVerifier.clear();
        } catch (e) { }
        window.transferRecaptchaVerifier = null;
      }

      const container = document.getElementById('transfer-recaptcha-container');
      if (container) {
        container.innerHTML = '';
      }

      window.transferRecaptchaVerifier = new RecaptchaVerifier(auth, 'transfer-recaptcha-container', {
        size: 'invisible',
        callback: () => { }
      });

      const appVerifier = window.transferRecaptchaVerifier;
      const formattedPhone = formatPhoneForFirebase(phoneNum);
      console.log("👉 Số điện thoại chuyển tiền gửi sang Firebase:", formattedPhone);
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, appVerifier);
      setConfirmationResult(confirmation);
    } catch (err) {
      console.error("Firebase SMS send failed:", err);
      setOtpError('Không thể gửi mã SMS OTP. Chi tiết: ' + err.message);
    } finally {
      setOtpLoading(false);
    }
  };

  const handleResendTransferOtp = (e) => {
    e.preventDefault();
    if (otpLoading) return;
    sendTransferOtp(userPhone);
  };

  const handleVerifyTransferOtp = async (e) => {
    e.preventDefault();
    const otpCode = otp.join('');
    if (otpCode.length < 6) {
      setOtpError('Vui lòng nhập đủ 6 chữ số OTP.');
      return;
    }

    if (!confirmationResult) {
      setOtpError('Chưa gửi được mã OTP. Vui lòng thử lại.');
      return;
    }

    setOtpLoading(true);
    setOtpError('');

    try {
      // 1. Xác thực OTP trên Firebase và lấy ID Token
      const credential = await confirmationResult.confirm(otpCode);
      const idToken = await credential.user.getIdToken();

      // 2. Gửi yêu cầu chuyển tiền kèm ID Token lên Backend
      const amountVal = parseInt(amount, 10);
      const res = await apiFetch('/transactions/transfer', {
        method: 'POST',
        body: JSON.stringify({
          receiver_account_number: receiverAccount,
          amount: amountVal,
          description: description,
          id_token: idToken
        })
      });

      const resData = await res.json();

      if (res.ok && resData.success) {
        setSuccessData(resData.data);
        setShowOtpModal(false);
      } else {
        setOtpError(resData.message || 'Giao dịch chuyển khoản thất bại. Vui lòng thử lại.');
      }
    } catch (err) {
      console.error("Lỗi xác minh Firebase OTP chuyển khoản:", err);
      setOtpError('Mã OTP không đúng hoặc đã hết hạn.');
    } finally {
      setOtpLoading(false);
    }
  };

  const handleCancelOtp = () => {
    setShowOtpModal(false);
    setConfirmationResult(null);
  };

  const handleOtpChange = (index, value) => {
    if (isNaN(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value;
    setOtp(newOtp);

    // Auto-focus next input
    if (value !== '' && index < 5) {
      inputsRef.current[index + 1].focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace' && otp[index] === '' && index > 0) {
      inputsRef.current[index - 1].focus();
    }
  };

  const formatCurrency = (amt) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amt);
  };

  const paymentAccount = accounts.find(acc => acc.account_type === 'PAYMENT');

  return (
    <>
      <Navbar />
      <div style={{
        display: 'flex',
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        padding: '40px 20px',
        minHeight: 'calc(100vh - 73px)'
      }}>
        {/* Invisible container for Firebase reCAPTCHA */}
        <div id="transfer-recaptcha-container"></div>

        <div className="glass-container" id="transfer-container">
          {!successData ? (
            <>
              <h1 id="transfer-title">Chuyển tiền</h1>
              <p className="subtitle" id="transfer-subtitle">Chuyển khoản nhanh liên ngân hàng 24/7</p>

              {error && (
                <div className="alert alert-danger" id="transfer-error-alert" role="alert">
                  {error}
                </div>
              )}

              <form onSubmit={handleTransferSubmit} id="transfer-form">
                {paymentAccount && (
                  <div className="form-group" id="source-account-group">
                    <label>Tài khoản nguồn</label>
                    <div style={{
                      padding: '14px 16px',
                      background: 'rgba(0, 0, 0, 0.3)',
                      border: '1px solid var(--glass-border)',
                      borderRadius: '12px',
                      fontSize: '0.95rem'
                    }}>
                      <div>Số TK: <strong>{paymentAccount.account_number}</strong></div>
                      <div style={{ color: 'var(--secondary)', marginTop: '4px', fontWeight: '600' }}>
                        Số dư khả dụng: {formatCurrency(paymentAccount.balance)}
                      </div>
                    </div>
                  </div>
                )}

                <div className="form-group">
                  <label htmlFor="receiver-input">Số tài khoản nhận</label>
                  <input
                    id="receiver-input"
                    type="text"
                    placeholder="Nhập số tài khoản thụ hưởng"
                    value={receiverAccount}
                    onChange={(e) => setReceiverAccount(e.target.value)}
                    required
                    disabled={loading}
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="amount-input">Số tiền chuyển (VND)</label>
                  <input
                    id="amount-input"
                    type="number"
                    placeholder="Ví dụ: 50000"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    required
                    disabled={loading}
                    min="1000"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="description-input">Nội dung chuyển khoản</label>
                  <textarea
                    id="description-input"
                    placeholder="Nhập nội dung chuyển khoản"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    disabled={loading}
                    rows="3"
                  />
                </div>

                <button
                  id="transfer-submit-btn"
                  type="submit"
                  className="btn btn-primary"
                  disabled={loading || !paymentAccount}
                >
                  {loading ? 'Đang thực hiện giao dịch...' : 'Xác nhận chuyển tiền'}
                </button>
              </form>
            </>
          ) : (
            <div style={{ textAlign: 'center' }} id="transfer-success-view">
              <h1 id="transfer-success-title" style={{ background: 'linear-gradient(135deg, #ffffff 30%, var(--success) 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                ✓ Giao dịch thành công
              </h1>
              <div className="alert alert-success" id="transfer-success-box" style={{ marginTop: '20px', textAlign: 'left', lineHeight: '1.8' }}>
                <div>Mã giao dịch: <strong>{successData.reference_code}</strong></div>
                <div>Số tài khoản nhận: <strong>{receiverAccount}</strong></div>
                <div>Số tiền: <strong style={{ color: 'var(--success)', fontSize: '1.1rem' }}>{formatCurrency(successData.amount)}</strong></div>
                <div>Nội dung: <strong>{successData.description}</strong></div>
                <div style={{ borderTop: '1px solid rgba(16, 185, 129, 0.2)', marginTop: '8px', paddingTop: '8px', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                  Trạng thái: {successData.status}
                </div>
              </div>

              <button
                id="transfer-back-btn"
                onClick={() => router.push('/dashboard')}
                className="btn btn-primary"
                style={{ marginTop: '20px' }}
              >
                Quay lại Dashboard
              </button>
            </div>
          )}
        </div>

        {/* OTP Verification Modal Overlay */}
        {showOtpModal && (
          <div style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(5, 6, 11, 0.85)',
            backdropFilter: 'blur(8px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '20px'
          }}>
            <div className="glass-container" style={{ maxWidth: '420px', border: '1px solid var(--primary)' }} id="transfer-otp-modal">
              <h2 style={{ fontSize: '1.5rem', marginBottom: '12px' }}>Xác thực giao dịch</h2>
              <p className="subtitle" style={{ fontSize: '0.9rem', marginBottom: '20px' }}>
                Chúng tôi đã gửi mã xác thực SMS OTP tới số điện thoại liên kết của bạn để xác thực giao dịch chuyển tiền.
              </p>

              {otpError && (
                <div className="alert alert-danger" role="alert" style={{ padding: '12px', fontSize: '0.9rem', marginBottom: '16px' }}>
                  {otpError}
                </div>
              )}

              <form onSubmit={handleVerifyTransferOtp}>
                <div className="otp-container" style={{ marginBottom: '24px' }}>
                  {otp.map((digit, index) => (
                    <input
                      key={index}
                      id={`transfer-otp-digit-${index}`}
                      ref={(el) => (inputsRef.current[index] = el)}
                      type="text"
                      maxLength="1"
                      className="otp-input"
                      style={{ width: '45px', height: '48px', fontSize: '1.25rem' }}
                      value={digit}
                      onChange={(e) => handleOtpChange(index, e.target.value)}
                      onKeyDown={(e) => handleKeyDown(index, e)}
                      disabled={otpLoading}
                      autoComplete="one-time-code"
                      required
                    />
                  ))}
                </div>

                <div style={{ display: 'flex', gap: '12px' }}>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={handleCancelOtp}
                    disabled={otpLoading}
                  >
                    Hủy
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={otpLoading || !confirmationResult}
                  >
                    {otpLoading ? 'Đang xử lý...' : 'Xác thực'}
                  </button>
                </div>

                <button
                  type="button"
                  className="btn btn-secondary"
                  style={{ marginTop: '12px', padding: '10px 16px', fontSize: '0.9rem' }}
                  onClick={handleResendTransferOtp}
                  disabled={otpLoading}
                >
                  Gửi lại mã OTP
                </button>
              </form>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
